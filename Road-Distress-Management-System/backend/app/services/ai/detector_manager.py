"""
Detector Manager responsible for orchestrating inference across road and signage detectors.
"""

import logging
from typing import Any, List, Dict

from app.services.ai.road_detector import RoadDetector
from app.services.ai.sign_detector import SignDetector

logger = logging.getLogger(__name__)


class MergedDetectionsList(list):
    """
    Hybrid response class that behaves like a standard list (for looping support)
    but also acts like a dictionary with keys: 'road_distresses', 'traffic_signs', and 'all_detections'.
    """
    def __init__(self, all_detections: List[Dict[str, Any]], road_distresses: List[Dict[str, Any]], traffic_signs: List[Dict[str, Any]]):
        super().__init__(all_detections)
        self.all_detections = all_detections
        self.road_distresses = road_distresses
        self.traffic_signs = traffic_signs
        self._dict_repr = {
            "road_distresses": road_distresses,
            "traffic_signs": traffic_signs,
            "all_detections": all_detections
        }

    def __getitem__(self, key):
        if isinstance(key, str):
            return self._dict_repr[key]
        return super().__getitem__(key)

    def get(self, key, default=None):
        return self._dict_repr.get(key, default)

    def keys(self):
        return self._dict_repr.keys()

    def values(self):
        return self._dict_repr.values()

    def items(self):
        return self._dict_repr.items()


class StandardBoxItem:
    """
    Simulates a standard YOLO box item with xyxy, conf, cls, and model_source properties.
    """
    def __init__(self, xyxy: List[float], conf: float, cls: int, model_source: str):
        self._xyxy = xyxy
        self._conf = conf
        self._cls = cls
        self.model_source = model_source

    @property
    def xyxy(self) -> Any:
        class XYXYList(list):
            def tolist(self):
                return self
        return XYXYList([self._xyxy])

    @property
    def conf(self) -> Any:
        class ConfItem(float):
            def item(self):
                return float(self)
            def __getitem__(self, idx):
                return self
        return ConfItem(self._conf)

    @property
    def cls(self) -> Any:
        class ClsItem(float):
            def item(self):
                return float(self)
            def __getitem__(self, idx):
                return self
        return ClsItem(self._cls)


class StandardBoxes:
    """
    Wraps standard box items to mimic Ultralytics Boxes collection.
    """
    def __init__(self, items: List[StandardBoxItem]):
        self.items = items

    def __len__(self) -> int:
        return len(self.items)

    def __iter__(self):
        return iter(self.items)

    def __getitem__(self, idx: int) -> StandardBoxItem:
        return self.items[idx]


class StandardResult:
    """
    Wraps merged boxes to mimic a single YOLO prediction Result.
    """
    def __init__(self, boxes: StandardBoxes):
        self.boxes = boxes


class DetectorManager:
    """
    Orchestrator to run dual-model inference and merge results.
    """
    _instance = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(DetectorManager, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self.road_detector = RoadDetector()
        self.sign_detector = SignDetector()
        self._initialized = True
        logger.info("DetectorManager initialized successfully.")

    def __call__(self, img: Any, **kwargs) -> List[StandardResult]:
        """
        Executes dual-model inference on a frame and merges detections.
        Offsets signage class IDs by 10 to avoid collision with road classes.
        """
        merged_boxes = []

        # 1. Run Road Distress Detector
        try:
            road_results = self.road_detector.detect(img, **kwargs)
            if road_results and len(road_results) > 0:
                result = road_results[0]
                if hasattr(result, "boxes"):
                    for box_item in result.boxes:
                        try:
                            xyxy_data = box_item.xyxy[0]
                            xyxy = xyxy_data.tolist() if hasattr(xyxy_data, "tolist") else list(xyxy_data)
                            
                            conf_data = box_item.conf
                            conf = float(conf_data.item()) if hasattr(conf_data, "item") else float(conf_data)
                            
                            cls_data = box_item.cls
                            cls_id = int(cls_data.item()) if hasattr(cls_data, "item") else int(cls_data)
                            
                            merged_boxes.append(StandardBoxItem(xyxy=xyxy, conf=conf, cls=cls_id, model_source="road"))
                        except Exception as e:
                            logger.warning(f"Error parsing road detector box item: {e}")
        except Exception as e:
            logger.error(f"DetectorManager: Road detector failed to execute: {e}", exc_info=True)

        # 2. Run Signage Detector
        try:
            sign_results = self.sign_detector.detect(img, **kwargs)
            if sign_results and len(sign_results) > 0:
                result = sign_results[0]
                if hasattr(result, "boxes"):
                    for box_item in result.boxes:
                        try:
                            xyxy_data = box_item.xyxy[0]
                            xyxy = xyxy_data.tolist() if hasattr(xyxy_data, "tolist") else list(xyxy_data)
                            
                            conf_data = box_item.conf
                            conf = float(conf_data.item()) if hasattr(conf_data, "item") else float(conf_data)
                            
                            cls_data = box_item.cls
                            cls_id = int(cls_data.item()) if hasattr(cls_data, "item") else int(cls_data)
                            offset_cls_id = cls_id + 10
                            
                            merged_boxes.append(StandardBoxItem(xyxy=xyxy, conf=conf, cls=offset_cls_id, model_source="signage"))
                        except Exception as e:
                            logger.warning(f"Error parsing signage detector box item: {e}")
        except Exception as e:
            logger.error(f"DetectorManager: Signage detector failed to execute: {e}", exc_info=True)

        logger.info(f"Merged {len(merged_boxes)} detections.")
        return [StandardResult(StandardBoxes(merged_boxes))]
