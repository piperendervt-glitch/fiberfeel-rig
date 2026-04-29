"""Analysis pipeline implementing the preregistered specification (§9).

The shape of every public function in this module mirrors the pseudocode
fixed in ``preregistration/2026-04-29_v1.md`` §9. Any divergence between
this implementation and §9 is a bug in this file (per CLAUDE.md, the
preregistration is normative; this file must be brought into line, the
preregistration is not to be edited).

Key rules from §9::

    alpha                            = 0.01
    test                             = Welch's t-test, two-tailed
    outlier flag                     = |x - median| > 3 * MAD
    outlier action                   = report only, do NOT exclude
    invalid_threshold_per_condition  = 3 (>3 outliers in 30 frames -> condition invalid)
    effect_size_threshold            = |delta| > 3 * sigma_baseline
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

import numpy as np
import scipy.stats
import yaml


# Preregistered constants — do not parameterize without an entry in deviations.md (§12).
ALPHA = 0.01
OUTLIER_MAD_K = 3
INVALID_OUTLIER_THRESHOLD = 3
EFFECT_SIZE_K_SIGMA = 3


@dataclass
class RoiConfig:
    cx: float
    cy: float
    r_fiber_px: float
    shrink_factor: float = 0.8

    @property
    def r_analysis_px(self) -> float:
        """ROI analysis radius = r_fiber * shrink_factor (§5.2)."""
        return self.r_fiber_px * self.shrink_factor

    @classmethod
    def from_yaml(cls, path: str | Path) -> "RoiConfig":
        with Path(path).open(encoding="utf-8") as f:
            data = yaml.safe_load(f)
        roi = data["roi"]
        for k in ("cx", "cy", "r_fiber_px"):
            if roi.get(k) == "TBD" or roi.get(k) is None:
                raise ValueError(
                    f"roi_config.yaml: roi.{k} is unresolved (TBD). "
                    "Determine ROI per preregistration §5.2 before analysis."
                )
        return cls(
            cx=float(roi["cx"]),
            cy=float(roi["cy"]),
            r_fiber_px=float(roi["r_fiber_px"]),
            shrink_factor=float(roi.get("shrink_factor", 0.8)),
        )


@dataclass
class ConditionStats:
    """Output of :func:`analyze_condition` — mirror of §9 dict."""

    mean: float
    std: float
    median: float
    n_outliers_3MAD: int
    valid: bool
    n_frames: int
    roi_sums: np.ndarray = field(repr=False)


@dataclass
class CompareResult:
    """Output of :func:`compare` — mirror of §9 dict."""

    t: float
    p: float
    delta: float
    delta_sigma: float

    def supports_effect(self) -> bool:
        """True iff |delta| exceeds the preregistered effect-size threshold (§9)."""
        return abs(self.delta_sigma) > EFFECT_SIZE_K_SIGMA

    def significant(self, alpha: float = ALPHA) -> bool:
        return self.p < alpha


def integrate_roi(frame: np.ndarray, roi: RoiConfig) -> float:
    """Sum of pixel values inside the circular ROI (§9 ``integrate_roi``).

    ``frame`` is expected to be a 2-D array of pixel intensities (the RAW
    Bayer plane, or a single channel after demosaic — the preregistration
    only specifies "ROI 内画素値合計" so summation is over whatever 2-D
    intensity array is supplied; the caller is responsible for being
    consistent across all conditions in a session).
    """
    if frame.ndim != 2:
        raise ValueError(
            f"integrate_roi expects a 2-D frame, got shape {frame.shape}. "
            "Preprocess the RAW Bayer or pick a single channel before calling."
        )
    h, w = frame.shape
    yy, xx = np.ogrid[:h, :w]
    mask = (xx - roi.cx) ** 2 + (yy - roi.cy) ** 2 <= roi.r_analysis_px ** 2
    return float(frame[mask].sum())


def analyze_condition(
    frames: Iterable[np.ndarray], roi: RoiConfig
) -> ConditionStats:
    """Reduce N frames to a single condition statistic (§9 ``analyze_condition``).

    Implementation mirrors the §9 pseudocode exactly:

    - per-frame ROI sum
    - mean / std(ddof=1) / median
    - outlier count using |x - median| > 3 * MAD
    - valid iff n_outliers <= 3 (§9 ``invalid_threshold_per_condition: 3``;
      "30 フレーム中、3 超で条件無効" = strict greater than 3)
    """
    roi_sums = np.asarray(
        [integrate_roi(np.asarray(f), roi) for f in frames], dtype=np.float64
    )
    if roi_sums.size == 0:
        raise ValueError("analyze_condition: zero frames passed.")

    median = float(np.median(roi_sums))
    mad = float(np.median(np.abs(roi_sums - median)))
    deviations = np.abs(roi_sums - median)
    n_outliers = int((deviations > OUTLIER_MAD_K * mad).sum()) if mad > 0 else 0

    return ConditionStats(
        mean=float(np.mean(roi_sums)),
        std=float(np.std(roi_sums, ddof=1)) if roi_sums.size > 1 else 0.0,
        median=median,
        n_outliers_3MAD=n_outliers,
        valid=n_outliers <= INVALID_OUTLIER_THRESHOLD,
        n_frames=int(roi_sums.size),
        roi_sums=roi_sums,
    )


def compare(
    cond_a_frames: np.ndarray | Iterable[float],
    cond_b_frames: np.ndarray | Iterable[float],
    sigma_baseline: float,
) -> CompareResult:
    """Welch's t-test, two-tailed (§9 ``compare``).

    Inputs are per-frame ROI sums for the two conditions (NOT raw frames).
    ``sigma_baseline`` is the preregistered σ from §5.1; passing the
    wrong scaling factor invalidates the |delta_sigma| comparison used by
    the decision rules (§10).
    """
    a = np.asarray(list(cond_a_frames), dtype=np.float64)
    b = np.asarray(list(cond_b_frames), dtype=np.float64)
    if sigma_baseline <= 0:
        raise ValueError(
            f"sigma_baseline must be > 0 (got {sigma_baseline}). "
            "Run §5.1 baseline acquisition before invoking compare()."
        )
    t, p = scipy.stats.ttest_ind(a, b, equal_var=False)
    delta = float(np.mean(a) - np.mean(b))
    return CompareResult(
        t=float(t),
        p=float(p),
        delta=delta,
        delta_sigma=delta / sigma_baseline,
    )


def load_baseline_sigma(run_config_path: str | Path) -> tuple[float, float]:
    """Read (sigma_baseline, mu_baseline) from run_config.yaml.

    Refuses to return TBD values — by §5.1 these must be filled in before
    any §9 / §10 analysis runs.
    """
    with Path(run_config_path).open(encoding="utf-8") as f:
        cfg = yaml.safe_load(f)
    bl = cfg.get("baseline", {})
    for k in ("sigma_baseline", "mu_baseline"):
        if bl.get(k) == "TBD" or bl.get(k) is None:
            raise ValueError(
                f"run_config.yaml: baseline.{k} is unresolved (TBD). "
                "Run §5.1 baseline acquisition and update run_config.yaml."
            )
    return float(bl["sigma_baseline"]), float(bl["mu_baseline"])


def load_session_frames(session_dir: str | Path) -> dict[str, dict[int, list[np.ndarray]]]:
    """Discover per-condition / per-repetition frame arrays under ``session_dir``.

    Returns a nested mapping ``{condition_id: {rep_index: [frame_ndarray, ...]}}``.

    NOTE: actual RAW (.dng) decoding is intentionally not implemented here —
    decoding 12-bit Bayer DNGs requires a libraw / rawpy dependency that
    we do not want to pin until the lab box is finalized. Stub out and
    raise so callers cannot silently get empty data.
    """
    raise NotImplementedError(
        "RAW (.dng) decoding is not yet wired up. Implement once the rawpy / "
        "libcamera-tools dependency is settled, then return the nested dict "
        "described in this docstring."
    )


__all__ = [
    "ALPHA",
    "OUTLIER_MAD_K",
    "INVALID_OUTLIER_THRESHOLD",
    "EFFECT_SIZE_K_SIGMA",
    "RoiConfig",
    "ConditionStats",
    "CompareResult",
    "integrate_roi",
    "analyze_condition",
    "compare",
    "load_baseline_sigma",
    "load_session_frames",
]
