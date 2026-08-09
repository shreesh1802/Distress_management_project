"""
CPU vs GPU inference benchmark for the road/signage YOLOX detection pipeline.

Loads the real trained checkpoints (models/road_best.pth, models/signage_best.pth)
through the same YOLOXDetector class the actual video-processing pipeline uses
(app/services/live/yolox_engine.py), samples real frames from an actual uploaded
video, and times inference -- separately reporting pure model forward-pass time
(the part a GPU actually accelerates) and full per-frame pipeline time (which
also includes CPU-bound preprocessing/postprocessing, so it won't shrink as
much as the forward pass does).

Usage:
    .venv/Scripts/python.exe scripts/benchmark_inference.py
    .venv/Scripts/python.exe scripts/benchmark_inference.py --frames 60 --video path/to/video.mp4
    .venv/Scripts/python.exe scripts/benchmark_inference.py --device cuda   # force GPU (errors if unavailable)
    .venv/Scripts/python.exe scripts/benchmark_inference.py --device cpu   # force CPU even if a GPU is present

Run this unmodified on both this laptop (CPU) and a rented GPU instance to get
a real, directly-comparable ms/frame number -- everything below the frame-count
line auto-detects whatever hardware it's run on.
"""

import argparse
import os
import statistics
import sys
import time

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")

import cv2
import torch

from app.services.live.yolox_engine import YOLOXDetector
from yolox.utils import postprocess

BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MODELS_DIR = os.path.join(BACKEND_ROOT, "models")

# Same construction the real pipeline uses (app/services/ai/model_loader.py) --
# test_size/conf/nms match production exactly, so this is a faithful benchmark
# of the actual configured models, not a synthetic stand-in.
YOLOX_CONF_THRESH = 0.6
YOLOX_NMS_THRESH = 0.45
MODEL_SPECS = [
    dict(
        model_source="road",
        fallback_ckpt=os.path.join(MODELS_DIR, "road_best.pth"),
        fallback_exp_name="yolox-m",
        fallback_num_classes=4,
        fallback_class_names=["longitudinal_crack", "transverse_crack", "alligator_crack", "pothole"],
    ),
    dict(
        model_source="signage",
        fallback_ckpt=os.path.join(MODELS_DIR, "signage_best.pth"),
        fallback_exp_name="yolox-s",
        fallback_num_classes=3,
        fallback_class_names=["TRAFFIC SIGN", "SIGN BOARD", "POLES"],
    ),
]

DEFAULT_VIDEO_CANDIDATES = [
    os.path.join(BACKEND_ROOT, "uploads", "videos", "99613c95ecb2483994062e8d72cef840_Client_Test_Video.mp4"),
    os.path.join(BACKEND_ROOT, "uploads", "videos", "900bd1b3b7e844d4ad1b87e813c1520a_test_video.mp4"),
]


def load_detector(spec: dict) -> YOLOXDetector:
    return YOLOXDetector(
        exp_file="",
        ckpt_file="",
        model_source=spec["model_source"],
        conf_thresh=YOLOX_CONF_THRESH,
        nms_thresh=YOLOX_NMS_THRESH,
        test_size=640,
        fallback_ckpt=spec["fallback_ckpt"],
        fallback_exp_name=spec["fallback_exp_name"],
        fallback_num_classes=spec["fallback_num_classes"],
        fallback_class_names=spec["fallback_class_names"],
    )


def sample_frames(video_path: str, count: int):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Could not open video: {video_path}")
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if total <= 0:
        raise RuntimeError(f"Video reports 0 frames: {video_path}")
    count = min(count, total)
    # Evenly spaced across the video rather than just the first N frames, so the
    # sample isn't biased toward whatever happens to be at the very start.
    indices = [int(i * total / count) for i in range(count)]
    frames = []
    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ok, frame = cap.read()
        if ok:
            frames.append(frame)
    cap.release()
    if not frames:
        raise RuntimeError(f"Failed to decode any frames from {video_path}")
    return frames


def run_forward_only(detector: YOLOXDetector, img_tensor: torch.Tensor):
    """Times just the model's forward pass on `device` -- the part a GPU speeds up."""
    with torch.no_grad():
        outputs = detector.model(img_tensor)
    return outputs


def benchmark_model(spec: dict, frames: list, device: torch.device):
    print(f"\nLoading {spec['model_source']} model ({spec['fallback_exp_name']})...")
    detector = load_detector(spec)
    detector.model.to(device)
    detector.model.eval()

    forward_times = []
    full_times = []

    for i, frame in enumerate(frames):
        t_full_start = time.perf_counter()

        height, width = frame.shape[:2]
        ratio = min(detector.exp.test_size[0] / height, detector.exp.test_size[1] / width)
        img, _ = detector.preproc(frame, None, detector.exp.test_size)
        img_tensor = torch.from_numpy(img).unsqueeze(0).float().to(device)

        if device.type == "cuda":
            torch.cuda.synchronize()
        t_fwd_start = time.perf_counter()

        outputs = run_forward_only(detector, img_tensor)

        if device.type == "cuda":
            torch.cuda.synchronize()
        t_fwd_end = time.perf_counter()

        outputs = postprocess(
            outputs, detector.exp.num_classes, detector.exp.test_conf,
            detector.exp.nmsthre, class_agnostic=True,
        )[0]

        t_full_end = time.perf_counter()

        is_warmup = i == 0
        if not is_warmup:
            forward_times.append((t_fwd_end - t_fwd_start) * 1000)
            full_times.append((t_full_end - t_full_start) * 1000)

    return forward_times, full_times


def summarize(label: str, times_ms: list):
    if not times_ms:
        print(f"  {label}: no samples")
        return
    print(
        f"  {label}: mean={statistics.mean(times_ms):.1f}ms  "
        f"median={statistics.median(times_ms):.1f}ms  "
        f"min={min(times_ms):.1f}ms  max={max(times_ms):.1f}ms  (n={len(times_ms)})"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--frames", type=int, default=30, help="Number of sample frames to benchmark (default: 30)")
    parser.add_argument("--video", type=str, default=None, help="Path to a video to sample frames from")
    parser.add_argument("--device", type=str, default=None, choices=["cpu", "cuda"], help="Force a device (default: auto-detect)")
    args = parser.parse_args()

    if args.device:
        device = torch.device(args.device)
        if device.type == "cuda" and not torch.cuda.is_available():
            print("ERROR: --device cuda requested but torch.cuda.is_available() is False.")
            sys.exit(1)
    else:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    print("=" * 70)
    print("  YOLOX ROAD/SIGNAGE PIPELINE INFERENCE BENCHMARK")
    print("=" * 70)
    print(f"  torch version   : {torch.__version__}")
    print(f"  device          : {device}")
    if device.type == "cuda":
        print(f"  GPU name        : {torch.cuda.get_device_name(device)}")
        print(f"  GPU memory      : {torch.cuda.get_device_properties(device).total_memory / (1024**3):.1f} GB")
    else:
        import platform
        print(f"  CPU             : {platform.processor() or 'unknown'}")

    video_path = args.video
    if not video_path:
        for candidate in DEFAULT_VIDEO_CANDIDATES:
            if os.path.exists(candidate):
                video_path = candidate
                break
    if not video_path or not os.path.exists(video_path):
        print("\nERROR: no video found. Pass one explicitly: --video path/to/video.mp4")
        sys.exit(1)

    print(f"  sample video    : {video_path}")
    print(f"  sample frames   : {args.frames} (+1 discarded warm-up frame)")

    frames = sample_frames(video_path, args.frames + 1)

    all_forward = []
    all_full = []
    for spec in MODEL_SPECS:
        fwd, full = benchmark_model(spec, frames, device)
        print(f"\n{spec['model_source'].upper()} model results:")
        summarize("Model forward pass only", fwd)
        summarize("Full per-frame (preproc+forward+postproc)", full)
        all_forward.extend(fwd)
        all_full.extend(full)

    print("\n" + "=" * 70)
    print("  COMBINED (both models, matching the real pipeline which runs both")
    print("  sequentially per frame)")
    print("=" * 70)
    if all_full:
        # Real per-frame pipeline cost = road model full time + signage model full
        # time for that same frame position, summed pairwise (both models run on
        # every frame in production).
        n = min(len(all_full) // 2, len(all_full))
        road_full = all_full[: len(frames) - 1]
        signage_full = all_full[len(frames) - 1:]
        combined_per_frame = [r + s for r, s in zip(road_full, signage_full)]
        summarize("Combined ms/frame (both models)", combined_per_frame)
        total_est_sec = statistics.mean(combined_per_frame) / 1000 * 3600  # 2min@30fps reference clip = 3600 frames
        print(f"\n  At this rate, a 2-minute/3600-frame 30fps video (our reference test) would take "
              f"~{total_est_sec/60:.1f} minutes end-to-end for AI inference alone")
        print("  (add frame extraction, video encoding, and DB writes on top -- inference is the dominant cost)")
    print()


if __name__ == "__main__":
    main()
