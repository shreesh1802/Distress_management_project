"""
Road Detector layer to run inference using the road distress YOLO model.
"""

import logging
from typing import Any, List
from app.services.ai.model_loader import ModelLoader

logger = logging.getLogger(__name__)


class RoadDetector:
    """
    Handles inference using the road distress detection model.
    """
    def __init__(self):
        logger.info("Loading Road Detection Model...")
        self.model = ModelLoader().load_road_model()
        logger.info("Road model loaded successfully.")

    def detect(self, img: Any, **kwargs) -> List[Any]:
        """
        Runs inference on the road distress detection model.
        """
        logger.info("Running Road Detection...")
        try:
            return self.model(img, **kwargs)
        except Exception as e:
            logger.error(f"RoadDetector detection failed: {e}", exc_info=True)
            return []
