"""
Wipes accumulated test/demo data so the app reflects only fresh runs.

This project's KPI widgets (Road Distresses' "Total Detections", Live
Processing's "Total Distresses", the GIS map's clustered markers, Upload
Video's "Files Uploaded") all query real, unscoped aggregates over the
whole database -- there's no per-session/per-demo scoping anywhere. That's
correct behavior for a real system, but during development it means every
test upload (including ones from earlier, since-fixed bugs -- the
MockYOLO era, the wrong-inference-resolution era, etc.) permanently
inflates those numbers, since nothing ever cleared the database between
test runs. This script clears it back to zero so a fresh demo/test
reflects only what you actually just uploaded.

Wipes: road_distresses, uploaded_videos, reports, maintenance_tasks
(all reset to empty, auto-increment IDs restarted from 1) and every file
under backend/uploads/ and <project-root>/reports/.

Leaves alone: the users table (in case real accounts were registered via
the API directly -- the Flutter app's own login is a hardcoded check, not
backed by this table, so this is almost never populated, but no reason to
touch it), the model weight files, and everything outside those two
upload/report directories.

Usage:
    python reset_test_data.py            # prompts for confirmation
    python reset_test_data.py --yes      # skips the prompt (for scripts)
"""

import argparse
import os
import shutil
import sys

from sqlalchemy import text

from app.db.session import SessionLocal

TABLES_TO_WIPE = ["road_distresses", "uploaded_videos", "reports", "maintenance_tasks"]

BACKEND_ROOT = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BACKEND_ROOT, ".."))

DIRS_TO_CLEAR = [
    os.path.join(BACKEND_ROOT, "uploads"),
    os.path.join(PROJECT_ROOT, "reports"),
]


def print_current_counts(db) -> None:
    print("Current row counts:")
    for table in TABLES_TO_WIPE:
        count = db.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar()
        print(f"  {table}: {count}")


def wipe_tables(db) -> None:
    # CASCADE handles the road_distresses -> uploaded_videos foreign key
    # (and any others) regardless of order; RESTART IDENTITY resets the
    # auto-increment sequences so new uploads start from id=1 again.
    table_list = ", ".join(TABLES_TO_WIPE)
    db.execute(text(f"TRUNCATE TABLE {table_list} RESTART IDENTITY CASCADE"))
    db.commit()
    print(f"Truncated: {table_list}")


def wipe_directory_contents(path: str) -> None:
    if not os.path.isdir(path):
        return
    for entry in os.listdir(path):
        full_path = os.path.join(path, entry)
        if os.path.isdir(full_path):
            shutil.rmtree(full_path)
        else:
            os.remove(full_path)
    print(f"Cleared contents of: {path}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--yes", "-y", action="store_true", help="Skip the interactive confirmation prompt.")
    args = parser.parse_args()

    db = SessionLocal()
    try:
        print_current_counts(db)
        print()
        print(f"This will PERMANENTLY delete all rows in: {', '.join(TABLES_TO_WIPE)}")
        print(f"and all files under: {', '.join(DIRS_TO_CLEAR)}")
        print()

        if not args.yes:
            answer = input("Type YES (all caps) to confirm, anything else to cancel: ")
            if answer != "YES":
                print("Cancelled -- nothing was deleted.")
                sys.exit(0)

        wipe_tables(db)
        for d in DIRS_TO_CLEAR:
            wipe_directory_contents(d)

        print()
        print("Done. The database and uploads/reports folders are now empty.")
        print("Restart the backend before uploading again (it needs to reload/reset its state).")
    finally:
        db.close()


if __name__ == "__main__":
    main()
