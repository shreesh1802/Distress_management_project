"""
Object tracking service layer to track road distress detections across consecutive frames.
Checks for IoU overlap, same class name, and frame proximity (<= 3 frames) to prevent duplicate inserts.
"""

import logging
from sqlalchemy.orm import Session
from app.crud.distress import create_distress
from app.schemas.distress import RoadDistressCreate
from app.services.ai.utils import generate_gps_coordinates_for_video

logger = logging.getLogger(__name__)


class RoadDistressTracker:
    """
    Lightweight custom object tracker using IoU, Class matching, and Frame Proximity (<= 3 frames).
    """
    def __init__(self, db: Session, max_frame_diff: int = 3, min_iou: float = 0.3):
        self.db = db
        self.max_frame_diff = max_frame_diff
        self.min_iou = min_iou
        # Tracks store structure:
        # {
        #   "tracking_id": int,
        #   "class_name": str,
        #   "first_frame": int,
        #   "last_frame": int,
        #   "first_timestamp": float,
        #   "last_timestamp": float,
        #   "last_bounding_box": list,
        #   "confidence_history": list,
        #   "detection_count": int,
        #   "distress_id": int
        # }
        self.tracks = []

    def compute_iou(self, boxA: list, boxB: list) -> float:
        """
        Calculates Intersection over Union (IoU) between two bounding boxes [x1, y1, x2, y2].
        """
        xA = max(boxA[0], boxB[0])
        yA = max(boxA[1], boxB[1])
        xB = min(boxA[2], boxB[2])
        yB = min(boxA[3], boxB[3])
        
        interArea = max(0, xB - xA) * max(0, yB - yA)
        
        boxAArea = (boxA[2] - boxA[0]) * (boxA[3] - boxA[1])
        boxBArea = (boxB[2] - boxB[0]) * (boxB[3] - boxB[1])
        
        unionArea = boxAArea + boxBArea - interArea
        if unionArea == 0:
            return 0.0
        return interArea / unionArea

    def track_detection(self, detection: dict, frame_number: int, timestamp: float, video_id: int):
        """
        Processes a single detection:
          - If matches active track (same class, frame diff <= 3, IoU >= 0.3): Updates track and saves metadata in DB
          - If no match: Creates and inserts a new RoadDistress record in PostgreSQL
        """
        class_name = detection["class_name"].lower()
        box = detection["box"]
        
        # 1. Look for matching active track
        matched_track = None
        iou = 0.0
        for track in self.tracks:
            # Rule 1: Must be same distress class
            if track["class_name"] != class_name:
                continue
                
            # Rule 2: Frame proximity check (difference <= 3 frames)
            frame_diff = abs(frame_number - track["last_frame"])
            if frame_diff > self.max_frame_diff:
                continue
                
            # Rule 3: Must satisfy minimum Intersection over Union (IoU) overlap
            curr_iou = self.compute_iou(box, track["last_bounding_box"])
            if curr_iou >= self.min_iou:
                matched_track = track
                iou = curr_iou
                break
                
        if matched_track:
            # Update matching track in-memory state
            matched_track["confidence_history"].append(detection["confidence"])
            matched_track["detection_count"] += 1
            matched_track["last_frame"] = frame_number
            matched_track["last_timestamp"] = timestamp
            matched_track["last_bounding_box"] = box
            
            logger.info(
                f"Tracker: Match found for track ID {matched_track['distress_id']} ({class_name}) "
                f"at frame {frame_number} (IoU: {iou:.2f}). Updating DB metadata."
            )
            
            # Update database record metadata
            from app.models.distress import RoadDistress
            db_distress = self.db.query(RoadDistress).filter(RoadDistress.id == matched_track["distress_id"]).first()
            if db_distress:
                db_distress.db_last_frame = frame_number
                db_distress.db_frames_visible = matched_track["detection_count"]
                
                base_path = db_distress.detection_image_path.split("?")[0] if db_distress.detection_image_path else ""
                conf_str = ",".join(str(c) for c in matched_track["confidence_history"])
                qs = (
                    f"last_frame={matched_track['last_frame']}&"
                    f"detection_count={matched_track['detection_count']}&"
                    f"last_timestamp={matched_track['last_timestamp']}&"
                    f"conf_history={conf_str}&"
                    f"last_box={box[0]},{box[1]},{box[2]},{box[3]}&"
                    f"damage_width_pixels={detection.get('damage_width_pixels', 0.0)}&"
                    f"damage_height_pixels={detection.get('damage_height_pixels', 0.0)}&"
                    f"damage_area_pixels={detection.get('damage_area_pixels', 0.0)}&"
                    f"damage_percentage_of_frame={detection.get('damage_percentage_of_frame', 0.0)}"
                )
                db_distress.detection_image_path = f"{base_path}?{qs}"
                try:
                    self.db.commit()
                except Exception as commit_err:
                    self.db.rollback()
                    logger.error(f"Failed to commit matched track updates for track {matched_track['distress_id']}: {commit_err}", exc_info=True)
            return None
        else:
            # Insert a new record
            lat, lon = generate_gps_coordinates_for_video(video_id, frame_number, timestamp)
            
            # Generate chainage placeholder
            base_km = int(lat * 5.7) + 12
            meters = int(lon * 135) % 1000
            chainage_str = f"KM {base_km}+{meters:03d}"
            logger.info(f"Tracker: Initializing new track. GPS: {lat}, {lon} (Chainage: {chainage_str})")
            
            distress_in = RoadDistressCreate(
                distress_type=detection["class_name"],
                severity=detection["severity"],
                confidence_score=detection["confidence"],
                latitude=lat,
                longitude=lon,
                image_url=detection["annotated_path"],
                status="detected",
                video_id=video_id,
                frame_number=frame_number,
                video_timestamp=timestamp,
                source_type="video",
                detection_image_path=detection["annotated_path"],
                first_frame=frame_number,
                last_frame=frame_number,
                frames_visible=1,
                model_source=detection.get("model_source", "road")
            )
            
            try:
                db_distress = create_distress(self.db, distress_in=distress_in)
                
                # Assign tracking_id to database ID and format initial metadata in path
                db_distress.tracking_id = db_distress.id
                base_path = db_distress.detection_image_path or ""
                qs = (
                    f"last_frame={frame_number}&"
                    f"detection_count=1&"
                    f"last_timestamp={timestamp}&"
                    f"conf_history={detection['confidence']}&"
                    f"last_box={box[0]},{box[1]},{box[2]},{box[3]}&"
                    f"damage_width_pixels={detection.get('damage_width_pixels', 0.0)}&"
                    f"damage_height_pixels={detection.get('damage_height_pixels', 0.0)}&"
                    f"damage_area_pixels={detection.get('damage_area_pixels', 0.0)}&"
                    f"damage_percentage_of_frame={detection.get('damage_percentage_of_frame', 0.0)}"
                )
                db_distress.detection_image_path = f"{base_path}?{qs}"
                self.db.commit()
            except Exception as new_track_err:
                self.db.rollback()
                logger.error(f"Failed to create new track for frame {frame_number}: {new_track_err}", exc_info=True)
                return None
            
            # Append new track state
            self.tracks.append({
                "tracking_id": db_distress.id,
                "class_name": class_name,
                "first_frame": frame_number,
                "last_frame": frame_number,
                "first_timestamp": timestamp,
                "last_timestamp": timestamp,
                "last_bounding_box": box,
                "confidence_history": [detection["confidence"]],
                "detection_count": 1,
                "distress_id": db_distress.id
            })
            
            return db_distress
