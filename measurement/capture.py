"""RAW frame capture for fiberfeel-rig.

Three modes:

* ``--mode shakedown`` — engineering verification, OUTSIDE the preregistration
  scope. Skips the run_config.yaml TBD checks. Exposure and frame count come
  from CLI flags. Frames are streamed and analyzed in-memory; saving to disk
  is optional via ``--save-to``. Data acquired this way must NOT enter the
  prereg §6 condition set or the §9 analysis pipeline.

* ``--mode baseline`` — acquires the 300-frame straight-fiber baseline that
  determines σ_baseline / μ_baseline (preregistration §5.1).

* ``--mode phase1`` — randomized 6-condition phase-1 acquisition with the
  control sandwich (preregistration §7 / §8.2).

Both ``baseline`` and ``phase1`` require run_config.yaml to be fully
resolved (no TBD values), and write frames as numpy ``.npy`` arrays
named ``<condition_id>_<frame_idx:03d>.npy`` under
``data/raw/<session_id>/``. Per-frame metadata (capture time, exposure,
gain, condition_id, session_id, sha256) is collected into
``metadata.yaml`` in the same directory.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
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
# Synthetic condition_id used for the baseline-mode files.
BASELINE_CONDITION_ID = "BASELINE"

# Shakedown defaults / thresholds (engineering values, NOT preregistered).
SHAKEDOWN_DEFAULT_EXPOSURE_US = 5000
SHAKEDOWN_DEFAULT_FRAMES = 5
SHAKEDOWN_FPS = 1.0
SHAKEDOWN_ROI_SIDE = 200
RAW_FULL_SCALE_12BIT = 4095
SATURATION_FRACTION = 0.95
LOW_BRIGHTNESS_FRACTION = 0.05


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
    """Configure and start the Picamera2 streaming pipeline.

    The returned camera is already streaming. The caller is responsible for
    calling :func:`_apply_camera_controls` once before measurement (to lock
    in ExposureTime / AnalogueGain after start) and ``cam.stop()`` at the
    end of the session.
    """
    if Picamera2 is None:
        raise RuntimeError(
            "picamera2 is not importable. capture.py must run on a Raspberry Pi "
            "with the picamera2 stack installed."
        )
    cam = Picamera2()
    # RAW (12-bit Bayer) configuration; preregistration §4 hardware.camera.
    # Request SBGGR12 explicitly. Newer picamera2/libcamera builds will then
    # deliver unpacked uint16 frames; older ones still negotiate the native
    # packed SBGGR12_CSI2P, which _ensure_unpacked_uint16 unpacks below.
    config = cam.create_still_configuration(
        raw={"size": cam.sensor_resolution, "format": "SBGGR12"},
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
    cam.start()
    return cam


def _apply_camera_controls(cam: "Picamera2", exposure_us: int) -> None:
    """Force ExposureTime / gain to take effect on a running camera.

    Picamera2 docs (Camera Controls): controls passed to
    create_still_configuration are only the *initial* values applied at the
    start of streaming; reliable runtime control needs an explicit
    set_controls() after start(). Without this, ExposureTime requests are
    silently ignored — which is exactly the symptom that motivated this
    function (CLI exposure 100us..50000us all returning saturated frames).

    The first 2-3 frames after set_controls still carry the previous sensor
    state; discard them before any measurement frame is captured.
    """
    cam.set_controls(
        {
            "ExposureTime": int(exposure_us),
            "AnalogueGain": 1.0,
            "AeEnable": False,
            "AwbEnable": False,
        }
    )
    for _ in range(3):
        request = cam.capture_request()
        request.release()


def _sha256_of_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _unpack_csi2p_12bit(packed: np.ndarray, width: int) -> np.ndarray:
    """Expand SBGGR12_CSI2P packed bytes to (h, width) uint16.

    CSI-2 RAW12 layout — every 3 bytes encode 2 pixels:
        byte 0 = high 8 bits of pixel 0
        byte 1 = high 8 bits of pixel 1
        byte 2 = low 4 of pixel 0 (lower nibble) | low 4 of pixel 1 (upper nibble)

    Stride padding beyond ``width * 3 // 2`` bytes is dropped before unpacking.
    """
    if width % 2 != 0:
        raise ValueError(f"_unpack_csi2p_12bit needs even width, got {width}")
    h, stride = packed.shape
    bytes_per_row = width * 3 // 2
    if stride < bytes_per_row:
        raise ValueError(
            f"packed stride {stride} < required {bytes_per_row} for width={width}"
        )
    chunks = packed[:, :bytes_per_row].reshape(h, width // 2, 3).astype(np.uint16)
    out = np.empty((h, width), dtype=np.uint16)
    out[:, 0::2] = (chunks[..., 0] << 4) | (chunks[..., 2] & 0x0F)
    out[:, 1::2] = (chunks[..., 1] << 4) | (chunks[..., 2] >> 4)
    return out


def _ensure_unpacked_uint16(
    arr: np.ndarray, width: int, height: int
) -> np.ndarray:
    """Normalize picamera2's RAW buffer to a (height, width) uint16 array.

    Picamera2 returns one of two shapes depending on what libcamera negotiated:
      * uint16 (height, >= width): unpacked 12-bit, value LSB-aligned in 16 bits.
      * uint8  (height, >= width * 3 // 2): SBGGR12_CSI2P packed; needs unpacking.

    Anything else is raised as a configuration error rather than silently
    returning bogus pixel values (the original bug this guards against).
    """
    if arr.ndim != 2 or arr.shape[0] != height:
        raise RuntimeError(
            f"Unexpected RAW buffer: shape={arr.shape}, expected first dim == {height}."
        )
    if arr.dtype == np.uint16 and arr.shape[1] >= width:
        return arr[:, :width] if arr.shape[1] != width else arr
    if arr.dtype == np.uint8 and arr.shape[1] >= width * 3 // 2:
        return _unpack_csi2p_12bit(arr, width)
    raise RuntimeError(
        f"Unexpected RAW buffer: dtype={arr.dtype}, shape={arr.shape}; "
        f"expected uint16(h, >={width}) or uint8(h, >={width * 3 // 2}) "
        f"with h={height}. Check picamera2 raw stream configuration."
    )


def _capture_one(cam: "Picamera2") -> tuple[np.ndarray, dict]:
    """Capture one frame, returning (raw_array, picamera2_metadata).

    The returned array is always unpacked uint16 of shape (height, width)
    holding 12-bit Bayer values in [0, 4095]. Both unpacked SBGGR12 and
    packed SBGGR12_CSI2P are accepted from picamera2 and normalized here.
    """
    raw_w, raw_h = cam.camera_configuration()["raw"]["size"]
    request = cam.capture_request()
    try:
        arr = np.asarray(request.make_array("raw"))
        metadata = request.get_metadata()
    finally:
        request.release()
    return _ensure_unpacked_uint16(arr, int(raw_w), int(raw_h)), metadata


def capture_condition(
    cam: "Picamera2",
    *,
    session_dir: Path,
    condition_id: str,
    n_frames: int,
    frame_idx_start: int = 0,
) -> list[dict]:
    """Capture ``n_frames`` and save each as ``<condition_id>_<frame_idx:03d>.npy``.

    ``frame_idx_start`` lets callers stack multiple repetitions of the same
    condition into one session_dir without filename collisions; rep_00 might
    use 0..29, rep_01 then 30..59, and so on.

    The camera must already be started (and warmed up via
    :func:`_apply_camera_controls`); the caller is responsible for
    ``cam.stop()`` at the end of the whole session.
    """
    session_dir.mkdir(parents=True, exist_ok=True)
    frames_meta: list[dict] = []
    for i in range(n_frames):
        frame_idx = frame_idx_start + i
        arr, picam_meta = _capture_one(cam)
        npy_path = session_dir / f"{condition_id}_{frame_idx:03d}.npy"
        np.save(npy_path, arr)
        frames_meta.append(
            {
                "condition_id": condition_id,
                "frame_idx": frame_idx,
                "filename": npy_path.name,
                "captured_at_iso": _utc_iso(),
                "ExposureTime_us": picam_meta.get("ExposureTime"),
                "AnalogueGain": picam_meta.get("AnalogueGain"),
                "SensorTimestamp_ns": picam_meta.get("SensorTimestamp"),
                "sha256": _sha256_of_file(npy_path),
            }
        )
    return frames_meta


def write_metadata(
    session_dir: Path, metadata: dict, filename: str = "metadata.yaml"
) -> Path:
    path = session_dir / filename
    with path.open("w", encoding="utf-8") as f:
        yaml.safe_dump(
            metadata, f,
            sort_keys=False, default_flow_style=False, allow_unicode=True,
        )
    return path


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
    try:
        _apply_camera_controls(cam, exposure_us)

        metadata: dict[str, Any] = {
            "session_id": run_cfg["session"]["session_id"],
            "operator": run_cfg["session"]["operator"],
            "phase": "phase1",
            "started_at_iso": _utc_iso(),
            "random_seed": seed,
            "phase1_order": order,
            "camera": run_cfg["camera"],
            "frames": [],
        }

        # §7: 冒頭・中央・末尾の C-CTRL-BL と冒頭末尾の C-CTRL-DARK / C-CTRL-SHAM。
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

        # frame_idx is global per (session, condition_id). Repetitions of the same
        # condition (e.g. C-CTRL-BL appearing 3+ times) get contiguous indices
        # rather than separate subdirectories — keeps filenames flat per the new
        # naming convention <condition_id>_<frame_idx:03d>.npy.
        next_idx: dict[str, int] = {}
        rep_count: dict[str, int] = {}
        for kind, cid in full_plan:
            spec = cond_by_id.get(cid) if kind == "phase1" else controls_by_id.get(cid)
            rep = rep_count.get(cid, 0)
            rep_count[cid] = rep + 1
            idx_start = next_idx.get(cid, 0)
            idx_end = idx_start + FRAMES_PER_CONDITION - 1

            _operator_action_prompt(
                f"Set up condition {cid} (rep {rep}): {spec}\n"
                f"        Frames: {cid}_{idx_start:03d}.npy ... {cid}_{idx_end:03d}.npy"
            )
            frames_meta = capture_condition(
                cam,
                session_dir=session_dir,
                condition_id=cid,
                n_frames=FRAMES_PER_CONDITION,
                frame_idx_start=idx_start,
            )
            for fm in frames_meta:
                fm["kind"] = kind
                fm["repetition"] = rep
                fm["condition_spec"] = spec
            metadata["frames"].extend(frames_meta)
            next_idx[cid] = idx_start + FRAMES_PER_CONDITION

        metadata["finished_at_iso"] = _utc_iso()
        write_metadata(
            session_dir, metadata,
            run_cfg["output"].get("metadata_filename", "metadata.yaml"),
        )
        return metadata
    finally:
        cam.stop()


def run_baseline(run_cfg: dict[str, Any], session_dir: Path) -> dict:
    """Acquire the 300-frame straight-fiber baseline (§5.1)."""
    fps = float(run_cfg["camera"]["frame_rate_fps"])
    exposure_us = int(run_cfg["camera"]["ExposureTime_us"])
    cam = _build_picam(exposure_us, fps)
    try:
        _apply_camera_controls(cam, exposure_us)

        metadata: dict[str, Any] = {
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
        frames_meta = capture_condition(
            cam,
            session_dir=session_dir,
            condition_id=BASELINE_CONDITION_ID,
            n_frames=BASELINE_FRAMES,
        )

        metadata.update(
            {
                "frames": frames_meta,
                "n_frames": len(frames_meta),
                "finished_at_iso": _utc_iso(),
            }
        )
        write_metadata(
            session_dir, metadata,
            run_cfg["output"].get("metadata_filename", "metadata.yaml"),
        )
        return metadata
    finally:
        cam.stop()


def run_shakedown(
    *,
    exposure_us: int,
    n_frames: int,
    save_to: Path | None = None,
    fps: float = SHAKEDOWN_FPS,
    roi_side: int = SHAKEDOWN_ROI_SIDE,
) -> None:
    """Engineering shakedown — OUTSIDE preregistration scope.

    Captures ``n_frames`` and prints per-frame max / mean / center-ROI stats
    plus saturation and low-brightness warnings against 12-bit full scale.
    Saves arrays only when ``save_to`` is supplied. Data from this mode must
    not feed §6 conditions or the §9 analysis pipeline.
    """
    cam = _build_picam(exposure_us, fps)
    try:
        _apply_camera_controls(cam, exposure_us)
        if save_to is not None:
            save_to.mkdir(parents=True, exist_ok=True)

        sat_threshold = RAW_FULL_SCALE_12BIT * SATURATION_FRACTION
        low_threshold = RAW_FULL_SCALE_12BIT * LOW_BRIGHTNESS_FRACTION
        half = roi_side // 2

        print("[SHAKEDOWN] engineering mode — OUTSIDE preregistration scope.", flush=True)
        print(
            f"[SHAKEDOWN] exposure={exposure_us}us  frames={n_frames}  "
            f"save_to={save_to}  roi={roi_side}x{roi_side}",
            flush=True,
        )
        print(
            f"[SHAKEDOWN] thresholds (12-bit full={RAW_FULL_SCALE_12BIT}): "
            f"saturation if max > {sat_threshold:.0f}; "
            f"low-brightness if mean < {low_threshold:.1f}",
            flush=True,
        )

        for i in range(n_frames):
            arr, _picam_meta = _capture_one(cam)
            # ROI = central roi_side x roi_side region of the first 2 axes.
            h, w = arr.shape[:2]
            cy, cx = h // 2, w // 2
            y0, y1 = max(0, cy - half), min(h, cy + half)
            x0, x1 = max(0, cx - half), min(w, cx + half)
            roi = arr[y0:y1, x0:x1]

            mx = float(arr.max())
            mn = float(arr.mean())
            roi_mean = float(roi.mean())
            roi_sum = float(roi.sum())

            warnings = []
            if mx > sat_threshold:
                warnings.append(f"SATURATION (max={mx:.0f} > {sat_threshold:.0f})")
            if mn < low_threshold:
                warnings.append(f"LOW_BRIGHTNESS (mean={mn:.1f} < {low_threshold:.1f})")
            warn_str = ("  WARN: " + "; ".join(warnings)) if warnings else ""

            print(
                f"[frame {i:03d}] shape={tuple(arr.shape)} dtype={arr.dtype} "
                f"max={mx:.0f} mean={mn:.1f}  roi(mean={roi_mean:.1f}, sum={roi_sum:.0f})"
                f"{warn_str}",
                flush=True,
            )

            if save_to is not None:
                p = save_to / f"shakedown_{i:03d}.npy"
                np.save(p, arr)
    finally:
        cam.stop()

    print(
        "[SHAKEDOWN] done. Reminder: log results in your engineering notebook; "
        "this data MUST NOT enter §6 conditions or the §9 analysis pipeline.",
        flush=True,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="fiberfeel-rig RAW capture")
    parser.add_argument(
        "--mode",
        choices=("shakedown", "baseline", "phase1"),
        required=True,
        help=(
            "shakedown = engineering check, OUTSIDE prereg scope; "
            "baseline = 300-frame sigma_baseline acquisition (§5.1); "
            "phase1 = randomized 6-condition acquisition (§7)."
        ),
    )
    parser.add_argument("--run-config", type=Path, default=DEFAULT_RUN_CONFIG,
                        help="(baseline / phase1) run_config.yaml path")
    parser.add_argument("--conditions", type=Path, default=DEFAULT_CONDITIONS,
                        help="(phase1) conditions.yaml path")

    # shakedown-only options (ignored in baseline / phase1).
    parser.add_argument("--exposure-us", type=int, default=SHAKEDOWN_DEFAULT_EXPOSURE_US,
                        help="(shakedown) exposure in microseconds, default 5000")
    parser.add_argument("--frames", type=int, default=SHAKEDOWN_DEFAULT_FRAMES,
                        help="(shakedown) number of frames to capture, default 5")
    parser.add_argument("--save-to", type=Path, default=None,
                        help="(shakedown) optional dir to save .npy frames; if omitted, no files written")
    args = parser.parse_args(argv)

    if args.mode == "shakedown":
        run_shakedown(
            exposure_us=args.exposure_us,
            n_frames=args.frames,
            save_to=args.save_to,
        )
        return 0

    # baseline / phase1 path: enforce the prereg's pre-measurement contract.
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
