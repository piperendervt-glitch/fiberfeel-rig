"""Decision rules implementing preregistration §10.

CLAUDE.md FORBIDS automated edits to this file. The decision rules are
the contractual content of the preregistration; if a rule needs to
change, it requires either (a) an entry in ``preregistration/deviations.md``
recorded BEFORE the change and accepted by the human investigator, or
(b) a fresh preregistration version. Mechanically syncing this file to
match observed data defeats the entire point of preregistration.

All rules from §10 are evaluated *simultaneously* on completed Phase 1
data (§10 final paragraph: "決定ルールは Phase 1 完了後に全部同時に評価する").
The order of fields below mirrors §10. Critical-severity rules are
evaluated independently of the hypothesis-discrimination rules.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Mapping

from analysis.pipeline import CompareResult, ConditionStats, EFFECT_SIZE_K_SIGMA


# ---------------------------------------------------------------------------
# §10 thresholds (preregistered constants — do not modify mechanically).
# ---------------------------------------------------------------------------
SHAM_DELTA_SIGMA_LIMIT = 3        # D-CRITICAL-SHAM: |Δ| > 3σ
DARK_FRACTION_OF_MU = 0.01        # D-CRITICAL-DARK: ROI > 1% of μ_baseline
DRIFT_DELTA_SIGMA_LIMIT = 2       # D-CRITICAL-DRIFT: head-tail BL diff > 2σ

H1_SUPPORT_DELTA_K = 3            # D-H1-SUPPORT: (05-02) > 3σ
H1_SUPPORT_JACKET_K = 3           # D-H1-SUPPORT: (04-02) < 3σ
H1_SUPPORT_ALPHA = 0.01           # D-H1-SUPPORT: Welch p < 0.01

H1_REJECT_DELTA_K = 1             # D-H1-REJECT: |05-02| < 1σ
H1_REJECT_ALPHA = 0.05            # D-H1-REJECT: Welch p > 0.05

AMBIGUOUS_LOW_K = 1               # D-AMBIGUOUS: 1σ < |Δ| < 3σ
AMBIGUOUS_HIGH_K = 3

H3_CHECK_DELTA_K = 1              # D-H3-CHECK: (06-05) < 1σ
PHASE2_MONOTONICITY_RHO_MIN = 0.7 # D-PHASE2-MONOTONICITY: Spearman ρ < 0.7


@dataclass
class RuleVerdict:
    rule_id: str
    fired: bool
    action: str
    severity: str = "info"     # one of: info, critical
    detail: dict = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Critical rules (evaluated even if hypothesis rules also fire).
# ---------------------------------------------------------------------------

def evaluate_d_critical_sham(
    sham_vs_baseline: CompareResult,
) -> RuleVerdict:
    """D-CRITICAL-SHAM: C-CTRL-SHAM の |Δ| > 3 * sigma_baseline."""
    fired = abs(sham_vs_baseline.delta_sigma) > SHAM_DELTA_SIGMA_LIMIT
    return RuleVerdict(
        rule_id="D-CRITICAL-SHAM",
        fired=fired,
        severity="critical",
        action="全データ凍結、装置診断、原因特定後に再開",
        detail={"delta_sigma": sham_vs_baseline.delta_sigma},
    )


def evaluate_d_critical_dark(
    dark_roi_value: float,
    mu_baseline: float,
) -> RuleVerdict:
    """D-CRITICAL-DARK: C-CTRL-DARK ROI value > 1% of μ_baseline."""
    fired = dark_roi_value > DARK_FRACTION_OF_MU * mu_baseline
    return RuleVerdict(
        rule_id="D-CRITICAL-DARK",
        fired=fired,
        severity="critical",
        action="遮光再構築、再測定",
        detail={
            "dark_roi_value": dark_roi_value,
            "limit_value": DARK_FRACTION_OF_MU * mu_baseline,
        },
    )


def evaluate_d_critical_drift(
    bl_head_mean: float,
    bl_tail_mean: float,
    sigma_baseline: float,
) -> RuleVerdict:
    """D-CRITICAL-DRIFT: head-tail BL difference > 2 * sigma_baseline."""
    delta_sigma = (bl_head_mean - bl_tail_mean) / sigma_baseline
    fired = abs(delta_sigma) > DRIFT_DELTA_SIGMA_LIMIT
    return RuleVerdict(
        rule_id="D-CRITICAL-DRIFT",
        fired=fired,
        severity="critical",
        action="セッション無効、再測定",
        detail={"delta_sigma": delta_sigma},
    )


# ---------------------------------------------------------------------------
# Hypothesis-discrimination rules (evaluated simultaneously per §10).
# ---------------------------------------------------------------------------

def evaluate_d_h1_support(
    cmp_05_vs_02: CompareResult,
    cmp_04_vs_02: CompareResult,
) -> RuleVerdict:
    """D-H1-SUPPORT: (05-02) > 3σ AND (04-02) < 3σ AND Welch p(05 vs 02) < 0.01."""
    fired = (
        cmp_05_vs_02.delta_sigma > H1_SUPPORT_DELTA_K
        and cmp_04_vs_02.delta_sigma < H1_SUPPORT_JACKET_K
        and cmp_05_vs_02.p < H1_SUPPORT_ALPHA
    )
    return RuleVerdict(
        rule_id="D-H1-SUPPORT",
        fired=fired,
        action="H1 支持として Phase 2 進行",
        detail={
            "delta_sigma_05_vs_02": cmp_05_vs_02.delta_sigma,
            "delta_sigma_04_vs_02": cmp_04_vs_02.delta_sigma,
            "p_05_vs_02": cmp_05_vs_02.p,
        },
    )


def evaluate_d_h1_reject(cmp_05_vs_02: CompareResult) -> RuleVerdict:
    """D-H1-REJECT: |05-02| < 1σ AND Welch p > 0.05."""
    fired = (
        abs(cmp_05_vs_02.delta_sigma) < H1_REJECT_DELTA_K
        and cmp_05_vs_02.p > H1_REJECT_ALPHA
    )
    return RuleVerdict(
        rule_id="D-H1-REJECT",
        fired=fired,
        action="H1 棄却、ネガティブ結果としてレポート",
        detail={
            "delta_sigma_05_vs_02": cmp_05_vs_02.delta_sigma,
            "p_05_vs_02": cmp_05_vs_02.p,
        },
    )


def evaluate_d_ambiguous(cmp_05_vs_02: CompareResult) -> RuleVerdict:
    """D-AMBIGUOUS: 1σ < |Δ| < 3σ on (C-P1-05 vs C-P1-02)."""
    abs_delta = abs(cmp_05_vs_02.delta_sigma)
    fired = AMBIGUOUS_LOW_K < abs_delta < AMBIGUOUS_HIGH_K
    return RuleVerdict(
        rule_id="D-AMBIGUOUS",
        fired=fired,
        action="setup_repetitions を 3 に増やして再測定 (§8.5)",
        detail={"abs_delta_sigma_05_vs_02": abs_delta},
    )


def evaluate_d_h3_check(cmp_06_vs_05: CompareResult) -> RuleVerdict:
    """D-H3-CHECK: (06-05) < 1σ -> 光学組成非依存、H3 候補。"""
    fired = cmp_06_vs_05.delta_sigma < H3_CHECK_DELTA_K
    return RuleVerdict(
        rule_id="D-H3-CHECK",
        fired=fired,
        action=(
            "光学組成非依存、H3 候補としてフラグ。"
            "Phase 2 進行は H1-SUPPORT または独立で signal がある場合のみ"
        ),
        detail={"delta_sigma_06_vs_05": cmp_06_vs_05.delta_sigma},
    )


def evaluate_d_h0(all_compares: Mapping[str, CompareResult]) -> RuleVerdict:
    """D-H0: Phase 1 全条件で |Δ| < 3 * sigma_baseline."""
    over_threshold = {
        k: v.delta_sigma for k, v in all_compares.items()
        if abs(v.delta_sigma) >= EFFECT_SIZE_K_SIGMA
    }
    fired = len(over_threshold) == 0
    return RuleVerdict(
        rule_id="D-H0",
        fired=fired,
        action="H0 採用、感度限界をレポート",
        detail={"comparisons_over_3sigma": over_threshold},
    )


def evaluate_d_phase2_monotonicity(spearman_rho: float) -> RuleVerdict:
    """D-PHASE2-MONOTONICITY: Phase 2 で R 単調性が崩れる (Spearman ρ < 0.7)."""
    fired = spearman_rho < PHASE2_MONOTONICITY_RHO_MIN
    return RuleVerdict(
        rule_id="D-PHASE2-MONOTONICITY",
        fired=fired,
        action="Phase 3 進行停止、診断",
        detail={"spearman_rho": spearman_rho},
    )


# ---------------------------------------------------------------------------
# Aggregator — call exactly once on a completed Phase 1 dataset.
# ---------------------------------------------------------------------------

def evaluate_phase1_all(
    *,
    cmp_05_vs_02: CompareResult,
    cmp_04_vs_02: CompareResult,
    cmp_06_vs_05: CompareResult,
    sham_vs_baseline: CompareResult,
    bl_head_mean: float,
    bl_tail_mean: float,
    sigma_baseline: float,
    mu_baseline: float,
    dark_roi_value: float,
    extra_compares: Mapping[str, CompareResult] | None = None,
) -> list[RuleVerdict]:
    """Evaluate ALL §10 rules simultaneously, in the order listed in §10."""
    all_compares = {
        "C-P1-05_vs_C-P1-02": cmp_05_vs_02,
        "C-P1-04_vs_C-P1-02": cmp_04_vs_02,
        "C-P1-06_vs_C-P1-05": cmp_06_vs_05,
    }
    if extra_compares:
        all_compares.update(extra_compares)

    return [
        evaluate_d_critical_sham(sham_vs_baseline),
        evaluate_d_critical_dark(dark_roi_value, mu_baseline),
        evaluate_d_critical_drift(bl_head_mean, bl_tail_mean, sigma_baseline),
        evaluate_d_h1_support(cmp_05_vs_02, cmp_04_vs_02),
        evaluate_d_h1_reject(cmp_05_vs_02),
        evaluate_d_ambiguous(cmp_05_vs_02),
        evaluate_d_h3_check(cmp_06_vs_05),
        evaluate_d_h0(all_compares),
    ]


__all__ = [
    "RuleVerdict",
    "evaluate_d_critical_sham",
    "evaluate_d_critical_dark",
    "evaluate_d_critical_drift",
    "evaluate_d_h1_support",
    "evaluate_d_h1_reject",
    "evaluate_d_ambiguous",
    "evaluate_d_h3_check",
    "evaluate_d_h0",
    "evaluate_d_phase2_monotonicity",
    "evaluate_phase1_all",
]
