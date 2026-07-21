"""
Sign Detector layer to run inference using the signage YOLO model.
"""

import logging
from typing import Any, List
from app.services.ai.model_loader import ModelLoader

logger = logging.getLogger(__name__)


class SignDetector:
    """
    Handles inference using the signage detection model.
    """
    def __init__(self):
        logger.info("Loading Signage Detection Model...")
        self.model = ModelLoader().load_signage_model()
        logger.info("Signage model loaded successfully.")

    def detect(self, img: Any, **kwargs) -> List[Any]:
        """
        Runs inference on the signage detection model.
        """
        logger.info("Running Traffic Sign Detection...")
        try:
            return self.model(img, **kwargs)
        except Exception as e:
            logger.error(f"SignDetector detection failed: {e}", exc_info=True)
            return []
