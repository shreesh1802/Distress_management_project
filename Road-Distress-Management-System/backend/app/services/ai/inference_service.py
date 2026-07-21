"""
Inference service layer to run prediction models on frame files and output annotated results on disk.
"""

import os
import cv2
import logging
from typing import List, Dict, Any, Optional
from app.services.ai.model_loader import ModelLoader
from app.services.ai.utils import map_class_id_to_name, map_confidence_to_severity, calculate_engineering_severity

logger = logging.getLogger(__name__)

# Standard color palette for bounding box annotations (BGR format for OpenCV)
# Keys must match the class names produced by app.services.ai.utils.CLASS_MAPPING
CLASS_COLORS = {
    # Road distress classes (RoadDetector): Red, Orange, Yellow
    "longitudinal_crack": (0, 255, 255),  # Yellow
    "transverse_crack": (0, 255, 255),    # Yellow
    "alligator_crack": (0, 165, 255),     # Orange
    "pothole": (0, 0, 255),               # Red
    # Signage classes (SignDetector): Blue, Green, Purple
    "TRAFFIC SIGN": (255, 0, 255),        # Purple/Magenta
    "SIGN BOARD": (0, 255, 0),            # Green
    "POLES": (255, 0, 0),                 # Blue
    "unknown": (255, 255, 255)            # White
}


def run_inference(frame_path_or_img, video_id: int, frame_number: Optional[int] = None) -> Any:
    """
    Executes deep learning (or mock) YOLO inference on a target frame.
    If detections are found, an annotated copy containing bounding boxes
    and prediction labels is saved under uploads/detections/{video_id}/.

    Args:
        frame_path_or_img (str or ndarray): Path to JPG file or numpy image array in memory.
        video_id (int): Database ID of the video record.
        frame_number (int, optional): The frame sequence number.

    Returns:
        MergedDetectionsList: List and Dict compatible collection of detections.
    """
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

    # Determine if frame is loaded in memory or from disk path
    if isinstance(frame_path_or_img, str):
        full_frame_path = os.path.join(base_dir, frame_path_or_img)
        if not os.path.exists(full_frame_path):
            raise FileNotFoundError(f"Source frame file not found: {full_frame_path}")
        img = cv2.imread(full_frame_path)
        frame_filename = os.path.basename(frame_path_or_img)
    else:
        img = frame_path_or_img
        frame_filename = f"frame_{frame_number:06d}.jpg" if frame_number is not None else "frame_000000.jpg"

    if img is None:
        raise ValueError("Image object is None.")

    # Lazily fetch model from model loader singleton (returns DetectorManager)
    model = ModelLoader().load_model()

    # Execute YOLO model prediction
    results = model(img)
    if not results or len(results) == 0:
        from app.services.ai.detector_manager import MergedDetectionsList
        return MergedDetectionsList([], [], [])

    result = results[0]
    boxes = result.boxes
    
    all_detections = []
    road_distresses = []
    traffic_signs = []

    # Ensure detections folder exists
    detections_dir = os.path.join(base_dir, "uploads", "detections", str(video_id))
    os.makedirs(detections_dir, exist_ok=True)

    # 1. Process all detected bounding box records and draw them
    for i in range(len(boxes)):
        try:
            box_item = boxes[i]
            
            # Extract coordinates
            xyxy_data = box_item.xyxy[0]
            if hasattr(xyxy_data, "tolist"):
                xyxy = xyxy_data.tolist()
            else:
                xyxy = list(xyxy_data)

            # Extract confidence score
            conf_data = box_item.conf
            if hasattr(conf_data, "item"):
                conf = float(conf_data.item())
            else:
                conf = float(conf_data)

            # Extract class index
            cls_data = box_item.cls
            if hasattr(cls_data, "item"):
                cls_id = int(cls_data.item())
            else:
                cls_id = int(cls_data)
                
            model_source = getattr(box_item, "model_source", "road")
        except (IndexError, TypeError, AttributeError, ValueError) as e:
            logger.warning(f"Error parsing box tensor elements: {e}")
            continue

        class_name = map_class_id_to_name(cls_id)
        x1, y1, x2, y2 = xyxy
        h, w = img.shape[:2]
        severity, metrics = calculate_engineering_severity(
            class_name=class_name,
            box=[x1, y1, x2, y2],
            frame_width=w,
            frame_height=h,
            confidence=conf
        )

        # Ensure values are integer coordinates for OpenCV drawing functions
        ix1, iy1, ix2, iy2 = int(x1), int(y1), int(x2), int(y2)

        # Draw bounding rectangle on frame copy
        color = CLASS_COLORS.get(class_name, CLASS_COLORS["unknown"])
        cv2.rectangle(img, (ix1, iy1), (ix2, iy2), color, 2)

        # Apply text labels just above the bounding boxes
        label = f"{class_name} ({conf:.2f})"
        cv2.putText(img, label, (ix1, max(15, iy1 - 8)), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

        # Keep a list of parsed coordinates and details
        detection_item = {
            "class_name": class_name,
            "class_id": cls_id,
            "confidence": round(conf, 4),
            "bbox": [round(c, 2) for c in xyxy],
            "box": [round(c, 2) for c in xyxy],
            "model_source": model_source,
            "severity": severity,
            "annotated_path": None,  # Will fill in after saving image
            "damage_width_pixels": metrics["damage_width_pixels"],
            "damage_height_pixels": metrics["damage_height_pixels"],
            "damage_area_pixels": metrics["damage_area_pixels"],
            "damage_percentage_of_frame": metrics["damage_percentage_of_frame"]
        }

        all_detections.append(detection_item)
        if model_source == "road":
            road_distresses.append(detection_item)
        else:
            traffic_signs.append(detection_item)

    # If no anomalies are detected, skip saving an annotated duplicate frame
    if len(all_detections) == 0:
        from app.services.ai.detector_manager import MergedDetectionsList
        return MergedDetectionsList([], [], [])

    # Save the composite annotated image frame to disk
    annotated_filename = f"annotated_{frame_filename}"
    annotated_filepath = os.path.join(detections_dir, annotated_filename)
    cv2.imwrite(annotated_filepath, img)

    relative_annotated_path = os.path.relpath(annotated_filepath, base_dir).replace("\\", "/")

    # Update relative path for all detections in this frame
    for det in all_detections:
        det["annotated_path"] = relative_annotated_path

    # Custom wrapper class supporting list indexing and dictionary keys
    from app.services.ai.detector_manager import MergedDetectionsList
    return MergedDetectionsList(all_detections, road_distresses, traffic_signs)
