"""
YOLOX inference engine for the live camera pipeline.

Direct port of the validated logic in webcam_test_combined.py: models are
loaded via exp files + checkpoints, frames preprocessed with ValTransform,
and outputs decoded with yolox.utils.postprocess. Class names come from the
exp object (YOLOX checkpoints do not embed class names).
"""

import os
os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")

import logging
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

try:
    import torch
    from yolox.data.data_augment import ValTransform
    from yolox.exp import get_exp
    from yolox.utils import postprocess
    YOLOX_AVAILABLE = True
except ImportError as _imp_err:
    YOLOX_AVAILABLE = False
    _IMPORT_ERROR = _imp_err


def _numpy_safe_globals() -> list:
    """
    Narrow allow-list that lets the project's own checkpoints load with
    ``weights_only=True``: they contain numpy scalars (best_ap / curr_ap) saved
    by older numpy versions. Nothing else is allowed to be unpickled.
    """
    import numpy as np
    allowed: list = [np.dtype]
    try:
        from numpy._core.multiarray import scalar as np_scalar  # numpy >= 2
    except ImportError:  # pragma: no cover - numpy < 2
        from numpy.core.multiarray import scalar as np_scalar
    allowed.append((np_scalar, "numpy.core.multiarray.scalar"))
    allowed.extend(getattr(np.dtypes, name) for name in dir(np.dtypes) if name.endswith("DType"))
    return allowed


def _allow_unsafe_checkpoint() -> bool:
    return os.getenv("YOLOX_ALLOW_UNSAFE_CHECKPOINT", "false").strip().lower() in ("1", "true", "yes", "on")


def _load_checkpoint(path: str):
    """
    Loads a checkpoint without executing arbitrary pickle code: ``weights_only=True``
    with a narrow numpy allow-list. Full unpickling (``weights_only=False``) is only
    possible when the operator explicitly sets YOLOX_ALLOW_UNSAFE_CHECKPOINT=true.
    """
    try:
        with torch.serialization.safe_globals(_numpy_safe_globals()):
            return torch.load(path, map_location="cpu", weights_only=True)
    except Exception as exc:
        if not _allow_unsafe_checkpoint():
            raise RuntimeError(
                "Checkpoint could not be loaded in safe (weights-only) mode; "
                "set YOLOX_ALLOW_UNSAFE_CHECKPOINT=true only for checkpoints you fully trust."
            ) from exc
        logger.warning("Falling back to UNSAFE full unpickling of %s (YOLOX_ALLOW_UNSAFE_CHECKPOINT=true).", path)
        if _allow_unsafe_checkpoint():  # guard: weights_only=False is reachable only behind the explicit flag
            return torch.load(path, map_location="cpu", weights_only=False)


def pick_device(requested: Optional[str]) -> "torch.device":
    """
    The device detection runs on. "auto" (the default) = the first NVIDIA GPU if PyTorch can use one,
    else the CPU. Asking for a GPU that is not there falls back to the CPU with a warning instead of
    failing, so the same settings work on a laptop and on a GPU machine.
    """
    choice = (requested or "auto").strip().lower()
    has_gpu = torch.cuda.is_available()
    if choice == "auto":
        return torch.device("cuda" if has_gpu else "cpu")
    if choice == "cpu":
        return torch.device("cpu")
    if choice == "cuda" or choice.startswith("cuda:"):
        if not has_gpu:
            logger.warning("LIVE_DEVICE=%s but PyTorch sees no CUDA GPU here; running on the CPU.", requested)
            return torch.device("cpu")
        device = torch.device(choice)
        if device.index is not None and device.index >= torch.cuda.device_count():
            logger.warning("LIVE_DEVICE=%s but only %d GPU(s) exist; using cuda:0.", requested,
                           torch.cuda.device_count())
            return torch.device("cuda:0")
        return device
    logger.warning("Unknown LIVE_DEVICE=%r (use auto, cpu, cuda or cuda:N); running on the CPU.", requested)
    return torch.device("cpu")


def use_half_precision(requested: Optional[str], device: "torch.device") -> bool:
    """float16 only makes sense on a GPU; "auto" turns it on there and leaves the CPU in float32."""
    choice = (requested or "auto").strip().lower()
    if device.type != "cuda":
        if choice in ("1", "true", "yes", "on"):
            logger.warning("LIVE_HALF_PRECISION is ignored on the CPU (float16 is slower there).")
        return False
    if choice in ("0", "false", "no", "off"):
        return False
    return True


class YOLOXDetector:
    """
    Wraps a single YOLOX model (exp file + checkpoint) behind a simple
    detect(frame) -> list[dict] interface. Loaded once, reused per frame.
    """

    def __init__(
        self,
        exp_file: str,
        ckpt_file: str,
        model_source: str,
        conf_thresh: float = 0.3,
        nms_thresh: float = 0.45,
        test_size: int = 320,
        fallback_ckpt: Optional[str] = None,
        fallback_exp_name: Optional[str] = None,
        fallback_num_classes: Optional[int] = None,
        fallback_class_names: Optional[List[str]] = None,
        device: Optional[str] = "auto",
        half_precision: Optional[str] = "auto",
    ):
        if not YOLOX_AVAILABLE:
            raise RuntimeError(f"YOLOX/torch not installed: {_IMPORT_ERROR}")

        self.model_source = model_source
        self.conf_thresh = conf_thresh

        use_fallback = not (os.path.exists(exp_file) and os.path.exists(ckpt_file))

        if use_fallback:
            if not (fallback_ckpt and os.path.exists(fallback_ckpt)):
                raise FileNotFoundError(
                    f"YOLOX '{model_source}' model unavailable: neither the configured "
                    f"exp/ckpt ({exp_file}, {ckpt_file}) nor the fallback checkpoint "
                    f"({fallback_ckpt}) exist on disk."
                )
            logger.warning(
                f"Configured exp/ckpt for '{model_source}' not found "
                f"({exp_file}, {ckpt_file}); falling back to {fallback_ckpt} using "
                f"the built-in '{fallback_exp_name}' architecture. Class names are "
                f"placeholders (not confirmed from an original exp file)."
            )
            self.exp = get_exp(exp_name=fallback_exp_name)
            self.exp.num_classes = fallback_num_classes
            ckpt_to_load = fallback_ckpt
            self.class_names = list(fallback_class_names)
            self.source = "fallback"
            self.exp_source = f"built-in:{fallback_exp_name}"
        else:
            logger.info(f"Loading YOLOX model '{model_source}' from {ckpt_file}")
            self.exp = get_exp(exp_file, None)
            ckpt_to_load = ckpt_file
            self.class_names = None  # set below from exp.class_names once loaded
            self.source = "configured"
            self.exp_source = exp_file

        self.ckpt_path = ckpt_to_load
        self.configured_exp_file = exp_file
        self.configured_ckpt_file = ckpt_file

        self.exp.test_conf = conf_thresh
        self.exp.nmsthre = nms_thresh
        self.exp.test_size = (test_size, test_size)

        self.model = self.exp.get_model()
        self.model.eval()

        ckpt = _load_checkpoint(ckpt_to_load)
        self.model.load_state_dict(ckpt["model"], strict=True)

        # The checkpoint is always read onto the CPU; move the model to the GPU when there is one.
        self.device = pick_device(device)
        self.half = use_half_precision(half_precision, self.device)
        self.model.to(self.device)
        if self.half:
            self.model.half()
        if self.device.type == "cuda":
            torch.backends.cudnn.benchmark = True   # every frame has the same input size
            self._warm_up()

        if not use_fallback:
            self.class_names = list(self.exp.class_names)

        self.preproc = ValTransform(legacy=False)
        logger.info(
            f"YOLOX '{model_source}' loaded ({'fallback' if use_fallback else 'configured'}) on "
            f"{self.device_label}. Classes: {self.class_names}"
        )

    @property
    def device_label(self) -> str:
        """e.g. "cpu" or "cuda (NVIDIA T4, float16)" -- shown in /live/status (no paths)."""
        device = getattr(self, "device", None)
        if device is None or device.type != "cuda":
            return "cpu"
        try:
            name = torch.cuda.get_device_name(device)
        except Exception:
            name = "GPU"
        return f"cuda ({name}, {'float16' if self.half else 'float32'})"

    def _warm_up(self) -> None:
        """One throw-away pass so the first real frame does not pay for GPU start-up."""
        try:
            size = self.exp.test_size
            dummy = torch.zeros((1, 3, size[0], size[1]), device=self.device)
            with torch.no_grad():
                self.model(dummy.half() if self.half else dummy)
            torch.cuda.synchronize(self.device)
        except Exception as exc:  # a failed warm-up only costs speed on the first frame
            logger.warning("GPU warm-up for '%s' failed: %s", self.model_source, exc)

    def detect(self, frame: Any) -> List[Dict[str, Any]]:
        """
        Run inference on a BGR frame.

        Returns detection dicts:
            class_name (str), confidence (float),
            box (list[float] [x1,y1,x2,y2] in original frame coords),
            model_source (str)
        """
        height, width = frame.shape[:2]
        ratio = min(self.exp.test_size[0] / height, self.exp.test_size[1] / width)

        img, _ = self.preproc(frame, None, self.exp.test_size)
        device = getattr(self, "device", None)
        img = torch.from_numpy(img).unsqueeze(0)
        if device is not None and device.type != "cpu":
            img = img.to(device, non_blocking=True)
        img = img.half() if getattr(self, "half", False) else img.float()

        with torch.no_grad():
            outputs = self.model(img)
            outputs = postprocess(
                outputs, self.exp.num_classes, self.exp.test_conf,
                self.exp.nmsthre, class_agnostic=True
            )[0]

        if outputs is None:
            return []

        # Back to the CPU in float32 for the box / score maths below (a no-op on the CPU path).
        outputs = outputs.cpu().float()
        bboxes = outputs[:, 0:4] / ratio
        scores = outputs[:, 4] * outputs[:, 5]
        classes = outputs[:, 6]

        detections: List[Dict[str, Any]] = []
        for box, score, cls in zip(bboxes, scores, classes):
            conf = float(score)
            if conf < self.conf_thresh:
                continue
            cls_id = int(cls)
            name = self.class_names[cls_id] if 0 <= cls_id < len(self.class_names) else "unknown"
            x1, y1, x2, y2 = [float(v) for v in box]
            detections.append({
                "class_name": name,
                "confidence": conf,
                "box": [x1, y1, x2, y2],
                "model_source": self.model_source,
                "class_id": cls_id,
            })
        return detections
