"""
Adds a fixed set of example distress detections to a video registered via
register_demo_video.py (or any completed video), for pilot/demo purposes.

This does NOT run real inference -- it can't, since there's no ground
truth for exactly where each distress type appears in an arbitrary
pre-annotated demo video. Instead it picks one evenly-spaced timestamp per
requested distress type, extracts that frame from the video's processed
(annotated) file, draws a bounding box using the same colors/label style
as the real pipeline's inference_service.py, and computes severity/damage
metrics via the same calculate_engineering_severity() function the real
pipeline uses -- so once a frame+box is picked, everything downstream of
that is the real computation, not a fabricated number.

Usage:
    python add_demo_detections.py --video-id 4
    python add_demo_detections.py --video-id 4 --types alligator,pothole

Distress types (matches app.services.ai.utils.CLASS_MAPPING exactly):
    longitudinal, transverse, alligator, pothole, poles, traffic_signs, sign_boards

Idempotent / no-duplicate guarantee: before inserting, each type is checked
against existing road_distresses rows for this video_id. If a row for that
type already exists, it's skipped rather than inserted again -- so re-running
this script (or asking for the same type twice) never produces two rows for
what should be a single instance, whether or not it happens to appear in
more than one nearby frame.
"""

import argparse
import os
import sys

import cv2
import imageio

from app.db.session import SessionLocal
from app.models.distress import RoadDistress
from app.models.video import UploadedVideo
from app.services.ai.utils import calculate_engineering_severity, generate_gps_coordinates_for_video
from app.crud.distress import create_distress
from app.schemas.distress import RoadDistressCreate

BACKEND_ROOT = os.path.dirname(os.path.abspath(__file__))

# Matches app.services.ai.inference_service.CLASS_COLORS (BGR for OpenCV).
CLASS_COLORS = {
    "longitudinal_crack": (0, 255, 255),
    "transverse_crack": (0, 255, 255),
    "alligator_crack": (0, 165, 255),
    "pothole": (0, 0, 255),
    "TRAFFIC SIGN": (255, 0, 255),
    "SIGN BOARD": (0, 255, 0),
    "POLES": (255, 0, 0),
}

# User-friendly shorthand -> real class name (app.services.ai.utils.CLASS_MAPPING).
TYPE_ALIASES = {
    "longitudinal": "longitudinal_crack",
    "transverse": "transverse_crack",
    "alligator": "alligator_crack",
    "pothole": "pothole",
    "poles": "POLES",
    "traffic_signs": "TRAFFIC SIGN",
    "sign_boards": "SIGN BOARD",
}

# Relative bounding-box placement (fraction of frame width/height) per class,
# roughly matching where each real-world object tends to sit in a forward-
# facing dashcam frame: pavement distresses low/centered on the road surface,
# signage elevated and off to one side.
BOX_LAYOUT = {
    "longitudinal_crack": (0.40, 0.72, 0.16, 0.09),
    "transverse_crack": (0.35, 0.78, 0.30, 0.06),
    "alligator_crack": (0.42, 0.68, 0.18, 0.14),
    "pothole": (0.46, 0.75, 0.10, 0.08),
    "TRAFFIC SIGN": (0.66, 0.18, 0.09, 0.13),
    "SIGN BOARD": (0.12, 0.22, 0.14, 0.10),
    "POLES": (0.70, 0.10, 0.04, 0.30),
}

DEFAULT_CONFIDENCE = {
    "longitudinal_crack": 0.86,
    "transverse_crack": 0.88,
    "alligator_crack": 0.91,
    "pothole": 0.93,
    "TRAFFIC SIGN": 0.89,
    "SIGN BOARD": 0.87,
    "POLES": 0.92,
}

DEFAULT_ORDER = [
    "alligator_crack",
    "transverse_crack",
    "pothole",
    "longitudinal_crack",
    "POLES",
    "TRAFFIC SIGN",
    "SIGN BOARD",
]


def extract_frame(video_path: str, timestamp: float, fps: float):
    reader = imageio.get_reader(video_path, format="FFMPEG")
    try:
        frame_index = max(0, int(round(timestamp * fps)))
        frame_index = min(frame_index, reader.count_frames() - 1)
        rgb_frame = reader.get_data(frame_index)
        return cv2.cvtColor(rgb_frame, cv2.COLOR_RGB2BGR), frame_index
    finally:
        reader.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--video-id", type=int, required=True, help="ID of the video to attach detections to.")
    parser.add_argument(
        "--types",
        default=None,
        help="Comma-separated subset of: longitudinal,transverse,alligator,pothole,poles,traffic_signs,sign_boards "
             "(default: all 7).",
    )
    args = parser.parse_args()

    if args.types:
        requested = []
        for raw in args.types.split(","):
            key = raw.strip().lower()
            if key not in TYPE_ALIASES:
                print(f"Unknown type '{raw}'. Valid options: {', '.join(TYPE_ALIASES.keys())}")
                sys.exit(1)
            requested.append(TYPE_ALIASES[key])
    else:
        requested = DEFAULT_ORDER

    db = SessionLocal()
    try:
        video = db.query(UploadedVideo).filter(UploadedVideo.id == args.video_id).first()
        if not video:
            print(f"No video with id={args.video_id} found.")
            sys.exit(1)

        video_path = None
        for candidate in (video.processed_filepath, video.processed_video_path, video.filepath):
            if candidate:
                full = os.path.join(BACKEND_ROOT, candidate)
                if os.path.exists(full):
                    video_path = full
                    break
        if not video_path:
            print(f"No playable video file found on disk for video id={args.video_id}.")
            sys.exit(1)

        reader = imageio.get_reader(video_path, format="FFMPEG")
        meta = reader.get_meta_data()
        fps = meta.get("fps", 30.0)
        duration = meta.get("duration")
        if not duration:
            duration = reader.count_frames() / fps
        reader.close()

        n = len(requested)
        # Spread across the middle 80% of the video so no pick lands on a
        # black lead-in/lead-out frame.
        timestamps = [duration * (0.1 + 0.8 * i / max(1, n - 1)) for i in range(n)]

        detections_dir = os.path.join(BACKEND_ROOT, "uploads", "detections", str(args.video_id))
        os.makedirs(detections_dir, exist_ok=True)

        created, skipped = 0, 0
        for class_name, timestamp in zip(requested, timestamps):
            existing = (
                db.query(RoadDistress)
                .filter(RoadDistress.video_id == args.video_id, RoadDistress.distress_type == class_name)
                .first()
            )
            if existing:
                print(f"Skipping {class_name}: a detection of this type already exists for video {args.video_id} (id={existing.id}).")
                skipped += 1
                continue

            frame_bgr, frame_index = extract_frame(video_path, timestamp, fps)
            h, w = frame_bgr.shape[:2]

            fx, fy, fw, fh = BOX_LAYOUT[class_name]
            x1, y1 = int(fx * w), int(fy * h)
            x2, y2 = int((fx + fw) * w), int((fy + fh) * h)
            confidence = DEFAULT_CONFIDENCE[class_name]

            color = CLASS_COLORS[class_name]
            cv2.rectangle(frame_bgr, (x1, y1), (x2, y2), color, 2)
            label = f"{class_name} ({confidence:.2f})"
            cv2.putText(frame_bgr, label, (x1, max(15, y1 - 8)), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

            safe_type = class_name.lower().replace(" ", "_")
            image_filename = f"annotated_demo_{safe_type}.jpg"
            image_filepath = os.path.join(detections_dir, image_filename)
            cv2.imwrite(image_filepath, frame_bgr)
            relative_image_path = os.path.relpath(image_filepath, BACKEND_ROOT).replace("\\", "/")

            severity, metrics = calculate_engineering_severity(
                class_name=class_name,
                box=[x1, y1, x2, y2],
                frame_width=w,
                frame_height=h,
                confidence=confidence,
            )
            lat, lon = generate_gps_coordinates_for_video(args.video_id, frame_index, timestamp)

            distress_in = RoadDistressCreate(
                distress_type=class_name,
                severity=severity,
                confidence_score=confidence,
                latitude=lat,
                longitude=lon,
                image_url=relative_image_path,
                status="detected",
                video_id=args.video_id,
                frame_number=frame_index,
                video_timestamp=round(timestamp, 2),
                source_type="video",
                detection_image_path=relative_image_path,
                first_frame=frame_index,
                last_frame=frame_index,
                frames_visible=1,
                model_source="road" if class_name in ("longitudinal_crack", "transverse_crack", "alligator_crack", "pothole") else "signage",
            )
            db_distress = create_distress(db, distress_in=distress_in)
            db_distress.tracking_id = db_distress.id
            db.commit()

            print(f"Added {class_name} at {timestamp:.1f}s (frame {frame_index}), severity={severity}, id={db_distress.id}")
            created += 1

        print()
        print(f"Done. {created} detection(s) added, {skipped} skipped (already existed).")
    finally:
        db.close()


if __name__ == "__main__":
    main()
