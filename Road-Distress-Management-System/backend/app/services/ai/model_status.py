"""
Cheap, side-effect free model status for /health.

Deliberately does NOT import torch / the model loader: if nothing has loaded a model yet
(the loader module is not in sys.modules) the models are reported as "not_loaded".
"""

import importlib.util
import os
import sys
from typing import Any, Dict

from app.core.config import settings


def get_model_status() -> Dict[str, Any]:
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

    def state(attr: str) -> str:
        mod = sys.modules.get("app.services.ai.model_loader")
        loader = getattr(mod, "ModelLoader", None) if mod else None
        instance = getattr(loader, "_instance", None) if loader else None
        model = getattr(instance, attr, None) if instance else None
        if model is None:
            return "not_loaded"
        return "mock" if isinstance(model, mod.MockYOLO) else "real"

    return {
        "yolox_runtime": importlib.util.find_spec("yolox") is not None and importlib.util.find_spec("torch") is not None,
        "road_weights_present": os.path.exists(os.path.join(base_dir, "models", "road_best.pth")),
        "signage_weights_present": os.path.exists(os.path.join(base_dir, "models", "signage_best.pth")),
        "mock_allowed": bool(settings.allow_mock_model),
        "road_model": state("_road_model"),
        "signage_model": state("_signage_model"),
    }
