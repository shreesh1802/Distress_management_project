"""
Full hardware/pipeline profiling report for the road/signage YOLOX pipeline.

Runs the real trained checkpoints (through the same YOLOXDetector class the
production pipeline uses) against a real video, and reports everything needed
to size a server/GPU/camera purchase:

  1. Estimated avg time for a full video to finish processing
  2. Frame size (pixel dimensions + bytes/frame in memory)
  3. Total frame count in the source video
  4. Input video resolution
  5. Video file size on disk (input, and output if it already exists)
  6. Input vs. output (processed/annotated) video resolution
  7. Preprocessing details (letterbox resize, padding, normalization) for
     input, and encoding details (codec/fps/pixel format) for output
  8. Inference time (pure model forward pass, per model + combined)
  9. Computation time (preprocessing + inference + postprocessing per frame,
     i.e. everything except reading the raw frame off disk)
 10. Resource usage during the run: RAM (process + system), CPU utilization,
     and GPU utilization + VRAM (via nvidia-smi, if a GPU is present)

Run identically on any candidate machine (this laptop's CPU, a GPU-equipped
machine, a rented cloud instance) to get directly comparable numbers.

Usage:
    .venv/Scripts/python.exe scripts/pipeline_profile_report.py
    .venv/Scripts/python.exe scripts/pipeline_profile_report.py --video path/to/video.mp4 --frames 30
    .venv/Scripts/python.exe scripts/pipeline_profile_report.py --device cuda
    .venv/Scripts/python.exe scripts/pipeline_profile_report.py --json report.json
"""

import argparse
import json
import os
import platform
import statistics
import subprocess
import sys
import threading
import time

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")

import cv2
import numpy as np
import psutil
import torch

from app.services.live.yolox_engine import YOLOXDetector
from yolox.utils import postprocess

BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MODELS_DIR = os.path.join(BACKEND_ROOT, "models")

YOLOX_CONF_THRESH = 0.6
YOLOX_NMS_THRESH = 0.45
TEST_SIZE = 640

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
# If a matching processed/annotated copy exists (video_id inferred from the
# uploads/processed/<id>/ folder), it's reported too for the input-vs-output
# resolution/encoding comparison. Best-effort only -- not required.
DEFAULT_PROCESSED_CANDIDATES = [
    os.path.join(BACKEND_ROOT, "uploads", "processed", "20", "processed_video.mp4"),
    os.path.join(BACKEND_ROOT, "uploads", "processed", "21", "processed_video.mp4"),
]


# --------------------------------------------------------------------------
# Resource monitor: samples system CPU%, this-process RAM, and (if present)
# GPU utilization/VRAM via nvidia-smi, on a background thread while inference
# runs, so timing isn't disturbed by the sampling itself.
# --------------------------------------------------------------------------
class ResourceMonitor:
    def __init__(self, interval_sec: float = 0.5):
        self.interval_sec = interval_sec
        self._stop = threading.Event()
        self._thread = None
        self.proc = psutil.Process(os.getpid())
        self.cpu_samples = []
        self.ram_process_mb_samples = []
        self.ram_system_used_pct_samples = []
        self.gpu_util_pct_samples = []
        self.gpu_mem_used_mb_samples = []
        self.has_nvidia_smi = self._check_nvidia_smi()

    def _check_nvidia_smi(self) -> bool:
        try:
            subprocess.run(["nvidia-smi", "-L"], capture_output=True, timeout=3, check=True)
            return True
        except Exception:
            return False

    def _sample_gpu(self):
        try:
            out = subprocess.run(
                ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used", "--format=csv,noheader,nounits"],
                capture_output=True, timeout=3, text=True, check=True,
            ).stdout.strip()
            util_str, mem_str = out.split(",")
            self.gpu_util_pct_samples.append(float(util_str.strip()))
            self.gpu_mem_used_mb_samples.append(float(mem_str.strip()))
        except Exception:
            pass

    def _run(self):
        self.proc.cpu_percent(interval=None)  # prime the internal counter
        while not self._stop.is_set():
            self.cpu_samples.append(self.proc.cpu_percent(interval=None))
            self.ram_process_mb_samples.append(self.proc.memory_info().rss / (1024 ** 2))
            self.ram_system_used_pct_samples.append(psutil.virtual_memory().percent)
            if self.has_nvidia_smi:
                self._sample_gpu()
            self._stop.wait(self.interval_sec)

    def start(self):
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=2)

    def summary(self) -> dict:
        def stats(samples):
            if not samples:
                return None
            return {"min": min(samples), "mean": round(statistics.mean(samples), 1), "max": max(samples)}

        return {
            "process_cpu_percent": stats(self.cpu_samples),
            "process_ram_mb": stats(self.ram_process_mb_samples),
            "system_ram_used_percent": stats(self.ram_system_used_pct_samples),
            "gpu_available": self.has_nvidia_smi,
            "gpu_utilization_percent": stats(self.gpu_util_pct_samples) if self.has_nvidia_smi else None,
            "gpu_memory_used_mb": stats(self.gpu_mem_used_mb_samples) if self.has_nvidia_smi else None,
        }


def video_metadata(path: str) -> dict:
    cap = cv2.VideoCapture(path)
    if not cap.isOpened():
        raise RuntimeError(f"Could not open video: {path}")
    meta = {
        "path": path,
        "width": int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
        "height": int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
        "fps": round(cap.get(cv2.CAP_PROP_FPS), 2),
        "total_frames": int(cap.get(cv2.CAP_PROP_FRAME_COUNT)),
        "file_size_mb": round(os.path.getsize(path) / (1024 ** 2), 1),
        "codec_fourcc": _fourcc_to_str(int(cap.get(cv2.CAP_PROP_FOURCC))),
    }
    cap.release()
    meta["duration_sec"] = round(meta["total_frames"] / meta["fps"], 1) if meta["fps"] else None
    return meta


def _fourcc_to_str(fourcc_int: int) -> str:
    return "".join([chr((fourcc_int >> (8 * i)) & 0xFF) for i in range(4)]).strip()


def sample_frames(video_path: str, count: int):
    cap = cv2.VideoCapture(video_path)
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    count = min(count, total)
    indices = [int(i * total / count) for i in range(count)]
    frames = []
    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ok, frame = cap.read()
        if ok:
            frames.append(frame)
    cap.release()
    return frames


def load_detector(spec: dict) -> YOLOXDetector:
    return YOLOXDetector(
        exp_file="", ckpt_file="", model_source=spec["model_source"],
        conf_thresh=YOLOX_CONF_THRESH, nms_thresh=YOLOX_NMS_THRESH, test_size=TEST_SIZE,
        fallback_ckpt=spec["fallback_ckpt"], fallback_exp_name=spec["fallback_exp_name"],
        fallback_num_classes=spec["fallback_num_classes"], fallback_class_names=spec["fallback_class_names"],
    )


def benchmark_model(spec: dict, frames: list, device: torch.device):
    print(f"  Loading {spec['model_source']} model ({spec['fallback_exp_name']})...")
    detector = load_detector(spec)
    detector.model.to(device)
    detector.model.eval()

    preproc_ms, infer_ms, postproc_ms, compute_ms = [], [], [], []

    for i, frame in enumerate(frames):
        t0 = time.perf_counter()
        height, width = frame.shape[:2]
        ratio = min(detector.exp.test_size[0] / height, detector.exp.test_size[1] / width)
        img, _ = detector.preproc(frame, None, detector.exp.test_size)
        img_tensor = torch.from_numpy(img).unsqueeze(0).float().to(device)
        t1 = time.perf_counter()

        if device.type == "cuda":
            torch.cuda.synchronize()
        with torch.no_grad():
            outputs = detector.model(img_tensor)
        if device.type == "cuda":
            torch.cuda.synchronize()
        t2 = time.perf_counter()

        outputs = postprocess(
            outputs, detector.exp.num_classes, detector.exp.test_conf, detector.exp.nmsthre, class_agnostic=True,
        )[0]
        t3 = time.perf_counter()

        if i == 0:
            continue  # discard warm-up frame
        preproc_ms.append((t1 - t0) * 1000)
        infer_ms.append((t2 - t1) * 1000)
        postproc_ms.append((t3 - t2) * 1000)
        compute_ms.append((t3 - t0) * 1000)

    return {
        "preprocessing_ms": _stats(preproc_ms),
        "inference_ms": _stats(infer_ms),
        "postprocessing_ms": _stats(postproc_ms),
        "computation_ms_total": _stats(compute_ms),
        "frame_size_at_model_input": f"{TEST_SIZE}x{TEST_SIZE} (letterboxed, padded)",
    }


def _stats(samples: list) -> dict:
    if not samples:
        return {}
    return {
        "mean": round(statistics.mean(samples), 2),
        "median": round(statistics.median(samples), 2),
        "min": round(min(samples), 2),
        "max": round(max(samples), 2),
        "n_samples": len(samples),
    }


def find_processed_pair(input_path: str):
    for candidate in DEFAULT_PROCESSED_CANDIDATES:
        if os.path.exists(candidate):
            return candidate
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--video", type=str, default=None, help="Path to input video")
    parser.add_argument("--processed-video", type=str, default=None, help="Path to the matching processed/annotated output video, if you have one")
    parser.add_argument("--frames", type=int, default=30, help="Number of sample frames to benchmark (default: 30)")
    parser.add_argument("--device", type=str, default=None, choices=["cpu", "cuda"])
    parser.add_argument("--json", type=str, default=None, help="Also write the full report as JSON to this path")
    args = parser.parse_args()

    if args.device:
        device = torch.device(args.device)
        if device.type == "cuda" and not torch.cuda.is_available():
            print("ERROR: --device cuda requested but torch.cuda.is_available() is False.")
            sys.exit(1)
    else:
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    video_path = args.video
    if not video_path:
        for candidate in DEFAULT_VIDEO_CANDIDATES:
            if os.path.exists(candidate):
                video_path = candidate
                break
    if not video_path or not os.path.exists(video_path):
        print("ERROR: no input video found. Pass one explicitly with --video.")
        sys.exit(1)

    processed_path = args.processed_video or find_processed_pair(video_path)

    report = {"generated_at": time.strftime("%Y-%m-%d %H:%M:%S")}

    # --- Environment ---
    report["environment"] = {
        "torch_version": torch.__version__,
        "device": str(device),
        "cpu_model": platform.processor() or "unknown",
        "cpu_logical_cores": psutil.cpu_count(logical=True),
        "cpu_physical_cores": psutil.cpu_count(logical=False),
        "system_total_ram_gb": round(psutil.virtual_memory().total / (1024 ** 3), 1),
    }
    if device.type == "cuda":
        report["environment"]["gpu_name"] = torch.cuda.get_device_name(device)
        report["environment"]["gpu_total_vram_gb"] = round(torch.cuda.get_device_properties(device).total_memory / (1024 ** 3), 1)

    # --- 3, 4, 5, 6 (input side): video metadata ---
    print("Reading input video metadata...")
    in_meta = video_metadata(video_path)
    report["input_video"] = in_meta

    frame_bytes = in_meta["width"] * in_meta["height"] * 3  # BGR uint8, no compression
    report["input_video"]["raw_frame_size_bytes"] = frame_bytes
    report["input_video"]["raw_frame_size_mb"] = round(frame_bytes / (1024 ** 2), 3)

    # --- 6 (output side) + 7 (output encoding) ---
    if processed_path and os.path.exists(processed_path):
        print("Reading processed/output video metadata...")
        out_meta = video_metadata(processed_path)
        report["output_video"] = out_meta
    else:
        report["output_video"] = {
            "note": "No processed/annotated video found to compare -- pass --processed-video path/to/file.mp4 "
                    "if you have one. Production pipeline writes output at the SAME resolution/fps as input "
                    "(app/services/pipeline/pipeline_manager.py), codec libx264 (H.264), pixel format yuv420p."
        }

    # --- 7 (input preprocessing detail) ---
    report["preprocessing"] = {
        "method": "Letterbox resize (aspect-ratio preserved) + gray padding, per yolox.data.data_augment.preproc()",
        "target_size": f"{TEST_SIZE}x{TEST_SIZE}",
        "resize_interpolation": "cv2.INTER_LINEAR (bilinear)",
        "padding_value": 114,
        "normalization": "None -- ValTransform(legacy=False) skips mean/std normalization; pixel values stay in raw 0-255 float32 range",
        "channel_order": "HWC (BGR) -> CHW",
        "note": "Same preprocessing applies to both the road and signage models -- only the target size (640x640) is shared; each model has its own weights.",
    }

    # --- 2, 8, 9: frame size at model input, inference time, computation time ---
    print(f"Sampling {args.frames} frames for timing...")
    frames = sample_frames(video_path, args.frames + 1)  # +1 for discarded warm-up

    monitor = ResourceMonitor()
    monitor.start()

    per_model = {}
    for spec in MODEL_SPECS:
        per_model[spec["model_source"]] = benchmark_model(spec, frames, device)

    monitor.stop()
    report["per_model_timing_ms"] = per_model
    report["resource_usage_during_benchmark"] = monitor.summary()

    # --- 1: estimated avg time for a full video ---
    road_compute = per_model["road"]["computation_ms_total"].get("mean", 0)
    signage_compute = per_model["signage"]["computation_ms_total"].get("mean", 0)
    combined_ms_per_frame = road_compute + signage_compute
    total_frames = in_meta["total_frames"]
    est_inference_only_sec = combined_ms_per_frame * total_frames / 1000

    report["full_video_estimate"] = {
        "combined_ms_per_frame_both_models": round(combined_ms_per_frame, 2),
        "total_frames_in_video": total_frames,
        "estimated_ai_inference_time_sec": round(est_inference_only_sec, 1),
        "estimated_ai_inference_time_min": round(est_inference_only_sec / 60, 2),
        "note": "This covers AI inference only (preprocessing+forward+postprocessing, both models, all frames). "
                "The real pipeline adds frame extraction/decode, object tracking, per-frame DB writes, and final "
                "video re-encoding on top -- inference is the dominant cost but not the only one.",
    }

    # --- print human-readable report ---
    _print_report(report)

    if args.json:
        with open(args.json, "w") as f:
            json.dump(report, f, indent=2)
        print(f"\nFull report written to {args.json}")


def _print_report(r: dict):
    print("\n" + "=" * 78)
    print("  PIPELINE PROFILE REPORT")
    print("=" * 78)

    e = r["environment"]
    print(f"\n[Environment]")
    print(f"  torch {e['torch_version']}  |  device: {e['device']}")
    print(f"  CPU: {e['cpu_model']}  ({e['cpu_physical_cores']} cores / {e['cpu_logical_cores']} threads)")
    print(f"  System RAM: {e['system_total_ram_gb']} GB")
    if "gpu_name" in e:
        print(f"  GPU: {e['gpu_name']}  ({e['gpu_total_vram_gb']} GB VRAM)")

    iv = r["input_video"]
    print(f"\n[Input video]  {iv['path']}")
    print(f"  Resolution      : {iv['width']}x{iv['height']}")
    print(f"  FPS             : {iv['fps']}")
    print(f"  Total frames    : {iv['total_frames']}")
    print(f"  Duration        : {iv['duration_sec']}s")
    print(f"  File size       : {iv['file_size_mb']} MB")
    print(f"  Codec (fourcc)  : {iv['codec_fourcc']}")
    print(f"  Raw frame size  : {iv['width']}x{iv['height']} = {iv['raw_frame_size_mb']} MB/frame uncompressed")

    ov = r["output_video"]
    print(f"\n[Output/processed video]")
    if "note" in ov and len(ov) == 1:
        print(f"  {ov['note']}")
    else:
        print(f"  Path            : {ov['path']}")
        print(f"  Resolution      : {ov['width']}x{ov['height']}")
        print(f"  FPS             : {ov['fps']}")
        print(f"  File size       : {ov['file_size_mb']} MB")
        print(f"  Codec (fourcc)  : {ov['codec_fourcc']}")

    p = r["preprocessing"]
    print(f"\n[Preprocessing -- applied to every frame before either model]")
    for k, v in p.items():
        print(f"  {k:22s}: {v}")

    print(f"\n[Per-model timing (ms), n={r['per_model_timing_ms']['road']['inference_ms'].get('n_samples', '?')} sampled frames]")
    for model_name, timing in r["per_model_timing_ms"].items():
        print(f"  {model_name.upper()}:")
        for stage in ("preprocessing_ms", "inference_ms", "postprocessing_ms", "computation_ms_total"):
            s = timing[stage]
            print(f"    {stage:22s}: mean={s['mean']:.1f}  median={s['median']:.1f}  min={s['min']:.1f}  max={s['max']:.1f}")

    ru = r["resource_usage_during_benchmark"]
    print(f"\n[Resource usage during benchmark]")
    if ru["process_cpu_percent"]:
        c = ru["process_cpu_percent"]
        print(f"  Process CPU %      : mean={c['mean']}  min={c['min']}  max={c['max']}")
    if ru["process_ram_mb"]:
        m = ru["process_ram_mb"]
        print(f"  Process RAM        : mean={m['mean']} MB  min={m['min']}  max={m['max']}")
    if ru["system_ram_used_percent"]:
        s = ru["system_ram_used_percent"]
        print(f"  System RAM used %  : mean={s['mean']}  min={s['min']}  max={s['max']}")
    if ru["gpu_available"] and ru["gpu_utilization_percent"]:
        g = ru["gpu_utilization_percent"]
        gm = ru["gpu_memory_used_mb"]
        print(f"  GPU utilization %  : mean={g['mean']}  min={g['min']}  max={g['max']}")
        print(f"  GPU VRAM used MB   : mean={gm['mean']}  min={gm['min']}  max={gm['max']}")
    elif not ru["gpu_available"]:
        print(f"  GPU: nvidia-smi not found -- no GPU utilization data (expected on CPU-only setups)")

    fv = r["full_video_estimate"]
    print(f"\n[Full-video estimate]")
    print(f"  Combined ms/frame (both models) : {fv['combined_ms_per_frame_both_models']}")
    print(f"  Total frames in this video       : {fv['total_frames_in_video']}")
    print(f"  Estimated AI inference time      : {fv['estimated_ai_inference_time_sec']}s "
          f"({fv['estimated_ai_inference_time_min']} min)")
    print(f"  Note: {fv['note']}")
    print()


if __name__ == "__main__":
    main()
