"""
Registers a video as "completed" using your own pre-made raw + annotated
video files, without running the real AI pipeline at all.

For demo/pilot presentations where you want a guaranteed-good example on
hand instead of depending on live inference (accuracy, timing, or codec
issues) -- Video Review just serves whatever file sits at the "processed
video" path for a given video record, so this works with the exact same
screen/endpoints as a normally-processed video; nothing else needs to
know this one was hand-registered.

Both input files are always re-encoded to H.264/yuv420p (matching the
real pipeline's generate_processed_video()) regardless of their original
codec, so this can't hit the "annotated video won't play in the browser"
class of bug already fixed in the real pipeline -- whatever tool you
made the annotated video with, this normalizes it to something every
browser can actually decode.

Usage:
    python register_demo_video.py --raw path/to/raw.mp4 --annotated path/to/annotated.mp4
    python register_demo_video.py --raw raw.mp4 --annotated annotated.mp4 --filename "Pilot Demo Run.mp4"

This does NOT create any road_distresses rows -- the Detections sidebar
on Video Review will show empty for a video registered this way. Ask if
you also want specific example detections added; that needs telling me
what to show (type, severity, approximate timestamp) rather than
guessing at a taxonomy the same way the pipeline debugging did.
"""

import argparse
import os
import shutil
import sys
import uuid
from datetime import datetime, timezone

import imageio

from app.db.session import SessionLocal
from app.models.video import UploadedVideo
from app.services.video import sanitize_filename

BACKEND_ROOT = os.path.dirname(os.path.abspath(__file__))


def reencode_to_h264(src_path: str, dst_path: str) -> None:
    """
    Re-encodes any input video to H.264/yuv420p via imageio's bundled
    ffmpeg (which has real libx264 support, unlike opencv-python's bundled
    build -- see the comment on generate_processed_video() in
    pipeline_manager.py for the full story). Guarantees browser
    playability regardless of the source file's original codec.
    """
    reader = imageio.get_reader(src_path, format='FFMPEG')
    meta = reader.get_meta_data()
    fps = meta.get('fps', 30.0)

    writer = imageio.get_writer(
        dst_path, fps=fps, codec='libx264', format='FFMPEG', pixelformat='yuv420p'
    )
    try:
        for frame in reader:
            writer.append_data(frame)
    finally:
        reader.close()
        writer.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--raw", required=True, help="Path to your raw/original video file.")
    parser.add_argument("--annotated", required=True, help="Path to your pre-made annotated video file.")
    parser.add_argument("--filename", default=None, help="Display filename (defaults to the raw file's own name).")
    args = parser.parse_args()

    if not os.path.isfile(args.raw):
        print(f"Raw video not found: {args.raw}")
        sys.exit(1)
    if not os.path.isfile(args.annotated):
        print(f"Annotated video not found: {args.annotated}")
        sys.exit(1)

    display_filename = args.filename or os.path.basename(args.raw)

    # 1. Copy the raw video into uploads/videos/, matching the same naming
    #    convention (and sanitize_filename call) real uploads use.
    videos_dir = os.path.join(BACKEND_ROOT, "uploads", "videos")
    os.makedirs(videos_dir, exist_ok=True)
    sanitized = sanitize_filename(display_filename)
    unique_filename = f"{uuid.uuid4().hex}_{sanitized}"
    raw_dest = os.path.join(videos_dir, unique_filename)
    print(f"Copying raw video to {raw_dest} ...")
    shutil.copyfile(args.raw, raw_dest)
    raw_relative = os.path.relpath(raw_dest, BACKEND_ROOT).replace("\\", "/")

    # 2. Create the DB record as already "completed", skipping process_video()
    #    entirely -- this is the actual bypass of the real pipeline.
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        video = UploadedVideo(
            filename=display_filename,
            filepath=raw_relative,
            processing_status="completed",
            processing_started_at=now,
            processing_completed_at=now,
            processing_duration=0.0,
            progress=100,
            processing_stage="Completed",
        )
        db.add(video)
        db.commit()
        db.refresh(video)
        video_id = video.id
        print(f"Created video record id={video_id}.")

        # 3. Re-encode the annotated video into uploads/processed/{id}/, the
        #    exact path generate_processed_video() would have used.
        processed_dir = os.path.join(BACKEND_ROOT, "uploads", "processed", str(video_id))
        os.makedirs(processed_dir, exist_ok=True)
        processed_dest = os.path.join(processed_dir, "processed_video.mp4")
        print(f"Re-encoding annotated video to H.264 at {processed_dest} ...")
        reencode_to_h264(args.annotated, processed_dest)
        processed_relative = os.path.relpath(processed_dest, BACKEND_ROOT).replace("\\", "/")

        video.processed_filepath = processed_relative
        video.processed_video_path = processed_relative
        db.commit()

        print()
        print(f"Done. Video ID {video_id} ('{display_filename}') is registered as completed.")
        print(f"Open it in the app at: /video-review/{video_id}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
