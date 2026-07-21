"""
Configuration for the live USB camera detection pipeline.

All values are overridable via environment variables so nothing is hardcoded
to one laptop. Defaults mirror the validated webcam_test_combined.py settings.
"""

import os

# Backend root = .../backend  (this file: backend/app/services/live/live_config.py)
BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
# Project root = parent of backend/ (where live_test/ lives)
PROJECT_ROOT = os.path.abspath(os.path.join(BACKEND_ROOT, ".."))

def _env(name: str, default):
    val = os.getenv(name)
    if val is None:
        return default
    if isinstance(default, int):
        return int(val)
    if isinstance(default, float):
        return float(val)
    return val

# ---- YOLOX model files (defaults match the live_test/ layout) ----
PAVEMENT_EXP_FILE = _env("LIVE_PAVEMENT_EXP", os.path.join(PROJECT_ROOT, "live_test", "pavement_yolox_m_exp.py"))
PAVEMENT_CKPT     = _env("LIVE_PAVEMENT_CKPT", os.path.join(PROJECT_ROOT, "live_test", "pavement_best_ckpt.pth"))
SIGNAGE_EXP_FILE  = _env("LIVE_SIGNAGE_EXP",  os.path.join(PROJECT_ROOT, "live_test", "signage_yolox_s_exp.py"))
SIGNAGE_CKPT      = _env("LIVE_SIGNAGE_CKPT", os.path.join(PROJECT_ROOT, "live_test", "signage_best_ckpt.pth"))

# ---- Inference settings (validated in webcam_test_combined.py) ----
CONF_THRESH = _env("LIVE_CONF_THRESH", 0.3)     # display threshold
NMS_THRESH  = _env("LIVE_NMS_THRESH", 0.45)
TEST_SIZE   = _env("LIVE_TEST_SIZE", 256)

# ---- Camera / cadence ----
DEFAULT_CAMERA_INDEX = _env("LIVE_CAMERA_INDEX", 1)   # 1 = external Lenovo webcam
CAPTURE_WIDTH  = _env("LIVE_CAPTURE_WIDTH", 640)
CAPTURE_HEIGHT = _env("LIVE_CAPTURE_HEIGHT", 480)
PROCESS_EVERY_N_FRAMES = _env("LIVE_PROCESS_EVERY_N_FRAMES", 5)
RUN_SIGNAGE_EVERY_N_INFERENCES = _env("LIVE_SIGNAGE_EVERY_N", 3)

# ---- Persistence policy (prevents flooding road_distresses at ~10 inf/sec) ----
PERSIST_CONF_THRESH = _env("LIVE_PERSIST_CONF", 0.45)   # min confidence to save a DB row
PERSIST_MIN_INTERVAL_SEC = _env("LIVE_PERSIST_INTERVAL", 5.0)  # per-class cooldown
SNAPSHOT_DIR = os.path.join(BACKEND_ROOT, "uploads", "detections", "live")

# ---- Default GPS base (laptop webcams have no GPS); jittered per detection ----
DEFAULT_LATITUDE  = _env("LIVE_DEFAULT_LAT", 30.3398)   # Patiala fallback
DEFAULT_LONGITUDE = _env("LIVE_DEFAULT_LON", 76.3869)

# ---- Annotation palettes (BGR), copied from webcam_test_combined.py ----
PAVEMENT_COLORS = {
    "longitudinal_crack": (255, 180, 0),
    "transverse_crack": (0, 255, 255),
    "alligator_crack": (0, 165, 255),
    "pothole": (0, 0, 255),
}
SIGNAGE_COLORS = {
    "TRAFFIC SIGN": (255, 0, 255),
    "SIGN BOARD": (0, 255, 0),
    "POLES": (200, 200, 200),
}
DEFAULT_COLOR = (255, 255, 255)

# ---- Fallback model source (used when the live_test/ exp/ckpt above are not
# present on this machine) ----
# Falls back to this repo's own backend/models/{road,signage}_best.pt checkpoints
# using the built-in YOLOX architectures already confirmed compatible with them:
# a strict state_dict load (zero missing/unexpected keys) verified road_best.pt
# is a YOLOX-M model (4 classes) and signage_best.pt is a YOLOX-S model (3
# classes) -- see app/services/ai/model_loader.py for the same derivation used
# by the offline video pipeline. The real training class names/order for
# signage aren't known without the original exp file, so these use the same
# honest placeholder names adopted in app/services/ai/utils.py::CLASS_MAPPING
# rather than guessing a specific taxonomy.
FALLBACK_PAVEMENT_CKPT = os.path.join(BACKEND_ROOT, "models", "road_best.pt")
FALLBACK_SIGNAGE_CKPT = os.path.join(BACKEND_ROOT, "models", "signage_best.pt")
FALLBACK_PAVEMENT_EXP_NAME = "yolox-m"
FALLBACK_SIGNAGE_EXP_NAME = "yolox-s"
FALLBACK_PAVEMENT_NUM_CLASSES = 4
FALLBACK_SIGNAGE_NUM_CLASSES = 3
FALLBACK_PAVEMENT_CLASS_NAMES = ["longitudinal_crack", "transverse_crack", "alligator_crack", "pothole"]
FALLBACK_SIGNAGE_CLASS_NAMES = ["TRAFFIC SIGN", "SIGN BOARD", "POLES"]
