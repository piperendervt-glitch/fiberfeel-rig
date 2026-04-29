"""RAW frame capture for fiberfeel-rig (preregistration §4 / §8.2 / §5.1).

Acquires 12-bit Bayer RAW frames from a Raspberry Pi HQ Camera using
picamera2, with controls fixed per the preregistration:

    AnalogueGain = 1.0
    AwbEnable    = False
    AeEnable     = False
    ExposureTime = run_config.yaml: camera.ExposureTime_us
    frame_rate   = run_config.yaml: camera.frame_rate_fps  (default 1 fps)

Condition ordering is randomized via numpy.random.default_rng(seed),
where ``seed`` is taken from run_config.yaml: randomization.random_seed.
The seed MUST be set in run_config.yaml and committed to git BEFORE
this script is invoked (preregistration §8.2).

Output layout::

    data/raw/<session_id>/
        manifest.json
        baseline/                  # only if --mode baseline
            frame_000000.dng
            ...
        <condition_id>/            # one directory per condition (e.g. C-P1-05)
            rep_00/
                frame_000000.dng
                ...
            rep_01/
                ...
"""

from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np
import yaml

try:
    from picamera2 import Picamera2  # type: ignore
except ImportError:  # pragma: no cover - allows non-Pi dev hosts to import
    Picamera2 = None  # set at runtime; capture functions will assert presence


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_RUN_CONFIG = REPO_ROOT / "measurement" / "run_config.yaml"
DEFAULT_CONDITIONS = REPO_ROOT / "measurement" / "conditions.yaml"

# Preregistration §5.1: 300 frames at 1 fps for sigma_baseline determination.
BASELINE_FRAMES = 300
# Preregistration §6: 30 frames per condition during phase 1.
FRAMES_PER_CONDITION = 30


def _utc_iso() -> str:
    return _dt.datetime.now(tz=_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_run_config(path: Path = DEFAULT_RUN_CONFIG) -> dict[str, Any]:
    with path.open(encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    # Refuse to run if any value the preregistration says must be fixed
    # before measurement is still TBD.
    required = {
        "session.session_id": cfg["session"]["session_id"],
        "camera.ExposureTime_us": cfg["camera"]["ExposureTime_us"],
        "randomization.random_seed": cfg["randomization"]["random_seed"],
    }
    missing = [k for k, v in required.items() if v == "TBD" or v is None]
    if missing:
        raise SystemExit(
            "run_config.yaml has unresolved TBD fields (commit values first):\n  "
            + "\n  ".join(missing)
        )
    return cfg


def load_conditions(path: Path = DEFAULT_CONDITIONS) -> dict[str, Any]:
    with path.open(encoding="utf-8") as f:
        return yaml.safe_load(f)


def randomized_phase1_order(conditions: list[dict], seed: int) -> list[str]:
    """Preregistration §8.2: numpy.random.default_rng(seed).permutation(condition_ids)."""
    ids = [c["id"] for c in conditions]
    rng = np.random.default_rng(seed)
    return list(rng.permutation(ids))


def _build_picam(exposure_us: int, fps: float) -> "Picamera2":
    if Picamera2 is None:
        raise RuntimeError(
            "picamera2 is not importable. capture.py must run on a Raspberry Pi "
            "with the picamera2 stack installed."
        )
    cam = Picamera2()
    # RAW (12-bit Bayer) configuration; preregistration §4 hardware.camera.
    config = cam.create_still_configuration(
        raw={"size": cam.sensor_resolution},
        controls={
            "ExposureTime": int(exposure_us),
            "AnalogueGain": 1.0,
            "AwbEnable": False,
            "AeEnable": False,
            "FrameDurationLimits": (
                int(1_000_000 / fps),
                int(1_000_000 / fps),
            ),
        },
    )
    cam.configure(config)
    return cam


def _sha256_of_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def capture_frames(cam: "Picamera2", out_dir: Path, n_frames: int) -> list[dict]:
    """Capture ``n_frames`` RAW frames into ``out_dir`` and return per-frame metadata."""
    out_dir.mkdir(parents=True, exist_ok=True)
    cam.start()
    frames_meta: list[dict] = []
    try:
        for i in range(n_frames):
            stem = f"frame_{i:06d}"
            dng_path = out_dir / f"{stem}.dng"
            # capture_file with a .dng extension produces an Adobe DNG of the RAW
            # Bayer stream when the configuration includes a "raw" stream.
            request = cam.capture_request()
            try:
                request.save_dng(str(dng_path))
                metadata = request.get_metadata()
            finally:
                request.release()
            frames_meta.append(
                {
                    "index": i,
                    "filename": dng_path.name,
                    "captured_at_iso": _utc_iso(),
                    "ExposureTime_us": metadata.get("ExposureTime"),
                    "AnalogueGain": metadata.get("AnalogueGain"),
                    "SensorTimestamp_ns": metadata.get("SensorTimestamp"),
                    "sha256": _sha256_of_file(dng_path),
                }
            )
    finally:
        cam.stop()
    return frames_meta


def write_manifest(session_dir: Path, manifest: dict, filename: str = "manifest.json") -> None:
    path = session_dir / filename
    with path.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)


def _operator_action_prompt(message: str) -> None:
    """Block until the operator confirms a manual setup step (jacket strip, PDMS placement, weight, etc.)."""
    print(f"\n[ACTION] {message}", flush=True)
    input("        Press Enter when ready to capture this condition... ")


def run_phase1(
    run_cfg: dict[str, Any],
    conditions_cfg: dict[str, Any],
    session_dir: Path,
) -> dict:
    """Execute phase 1 acquisition (§7 Phase 1)."""
    seed = int(run_cfg["randomization"]["random_seed"])
    order = randomized_phase1_order(conditions_cfg["phase1_conditions"], seed)
    cond_by_id = {c["id"]: c for c in conditions_cfg["phase1_conditions"]}
    controls_by_id = {c["id"]: c for c in conditions_cfg["control_conditions"]}

    fps = float(run_cfg["camera"]["frame_rate_fps"])
    exposure_us = int(run_cfg["camera"]["ExposureTime_us"])
    cam = _build_picam(exposure_us, fps)

    manifest: dict[str, Any] = {
        "session_id": run_cfg["session"]["session_id"],
        "operator": run_cfg["session"]["operator"],
        "phase": "phase1",
        "started_at_iso": _utc_iso(),
        "random_seed": seed,
        "phase1_order": order,
        "camera": run_cfg["camera"],
        "conditions": [],
    }

    # §7: 冒頭・中央・末尾の C-CTRL-BL と冒頭末尾の C-CTRL-DARK / C-CTRL-SHAM。
    # ここでは骨組みとして冒頭シーケンス → ランダム順 phase1 → 末尾シーケンスを定義。
    # 中央 BL は phase1 の中点で挿入する。
    head_seq = ["C-CTRL-DARK", "C-CTRL-SHAM", "C-CTRL-BL"]
    tail_seq = ["C-CTRL-BL", "C-CTRL-SHAM", "C-CTRL-DARK"]
    mid_idx = len(order) // 2
    full_plan: list[tuple[str, str]] = (
        [("control", c) for c in head_seq]
        + [("phase1", order[i]) for i in range(mid_idx)]
        + [("control", "C-CTRL-BL")]
        + [("phase1", order[i]) for i in range(mid_idx, len(order))]
        + [("control", c) for c in tail_seq]
    )

    rep_count: dict[str, int] = {}
    for kind, cid in full_plan:
        spec = cond_by_id.get(cid) if kind == "phase1" else controls_by_id.get(cid)
        rep = rep_count.get(cid, 0)
        rep_count[cid] = rep + 1

        target_dir = session_dir / cid / f"rep_{rep:02d}"

        _operator_action_prompt(
            f"Set up condition {cid}: {spec}\n"
            f"        Output → {target_dir}"
        )
        frames_meta = capture_frames(cam, target_dir, FRAMES_PER_CONDITION)

        manifest["conditions"].append(
            {
                "kind": kind,
                "condition_id": cid,
                "repetition": rep,
                "spec": spec,
                "frames_dir": str(target_dir.relative_to(session_dir)),
                "n_frames": len(frames_meta),
                "frames": frames_meta,
            }
        )

    manifest["finished_at_iso"] = _utc_iso()
    write_manifest(session_dir, manifest, run_cfg["output"]["manifest_filename"])
    return manifest


def run_baseline(run_cfg: dict[str, Any], session_dir: Path) -> dict:
    """Acquire the 300-frame straight-fiber baseline (§5.1)."""
    fps = float(run_cfg["camera"]["frame_rate_fps"])
    exposure_us = int(run_cfg["camera"]["ExposureTime_us"])
    cam = _build_picam(exposure_us, fps)

    manifest: dict[str, Any] = {
        "session_id": run_cfg["session"]["session_id"],
        "operator": run_cfg["session"]["operator"],
        "phase": "baseline",
        "started_at_iso": _utc_iso(),
        "camera": run_cfg["camera"],
    }

    _operator_action_prompt(
        "Mount straight fiber (no bend, no PDMS, no weight). "
        "Confirm LED warmed up >= 30 minutes."
    )
    frames_meta = capture_frames(cam, session_dir / "baseline", BASELINE_FRAMES)

    manifest.update(
        {
            "n_frames": len(frames_meta),
            "frames": frames_meta,
            "finished_at_iso": _utc_iso(),
        }
    )
    write_manifest(session_dir, manifest, run_cfg["output"]["manifest_filename"])
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="fiberfeel-rig RAW capture")
    parser.add_argument(
        "--mode",
        choices=("baseline", "phase1"),
        required=True,
        help="baseline = 300-frame sigma_baseline acquisition (§5.1); "
             "phase1 = randomized 6-condition acquisition (§7).",
    )
    parser.add_argument("--run-config", type=Path, default=DEFAULT_RUN_CONFIG)
    parser.add_argument("--conditions", type=Path, default=DEFAULT_CONDITIONS)
    args = parser.parse_args(argv)

    run_cfg = load_run_config(args.run_config)
    conditions_cfg = load_conditions(args.conditions)

    session_id = run_cfg["session"]["session_id"]
    raw_root = REPO_ROOT / run_cfg["output"]["raw_dir"]
    session_dir = raw_root / session_id
    if session_dir.exists() and any(session_dir.iterdir()):
        raise SystemExit(
            f"Refusing to overwrite existing session directory: {session_dir}\n"
            "Pick a fresh session_id (raw data is append-only per §8.6)."
        )
    session_dir.mkdir(parents=True, exist_ok=True)

    if args.mode == "baseline":
        run_baseline(run_cfg, session_dir)
    else:
        run_phase1(run_cfg, conditions_cfg, session_dir)

    print(f"Done. Session written to: {session_dir}", flush=True)
    print(
        "Reminder: tar + sha256 the session and append to data/raw/checksums.txt (§8.6).",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
