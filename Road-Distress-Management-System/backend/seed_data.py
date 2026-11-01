"""
Database Seeding Script for Road Distress Management System.
Populates the (local, SQLite) database with demo data -- refuses to run in production
or against a non-SQLite database unless ALLOW_DESTRUCTIVE_SCRIPTS is set (app/core/env_guard.py).
Demo accounts get no password (sign in with Email + OTP). Populates:
- 3 users (Admin, Inspector, Maintenance lead)
- 20 realistic geo-tagged road distress logs
- 10 uploaded video logs
- 15 maintenance scheduling tasks
- 10 reports
"""

import sys
import logging
from datetime import datetime, timedelta
from sqlalchemy import text
from app.db.session import SessionLocal, engine
from app.models.user import User
from app.models.distress import RoadDistress
from app.models.video import UploadedVideo
from app.models.maintenance import MaintenanceTask
from app.models.report import Report
from app.core.security import UNUSABLE_PASSWORD

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)


def main():
    from app.core.env_guard import require_safe_environment
    require_safe_environment("seed_data.py")
    logger.info("Initializing database seeding...")
    db = SessionLocal()
    try:
        # 1. Clean existing records (avoid clearing alembic history)
        logger.info("Clearing existing records...")
        db.query(MaintenanceTask).delete()
        db.query(Report).delete()
        db.query(UploadedVideo).delete()
        db.query(RoadDistress).delete()
        db.query(User).delete()
        db.commit()

        # 2. Seed Users
        logger.info("Seeding users...")
        users = [
            User(
                email="admin@roaddistress.org",
                full_name="System Administrator",
                hashed_password=UNUSABLE_PASSWORD,
                role="admin"
            ),
            User(
                email="inspector.patel@roaddistress.org",
                full_name="Rajesh Patel",
                hashed_password=UNUSABLE_PASSWORD,
                role="inspector"
            ),
            User(
                email="maintenance.crew@roaddistress.org",
                full_name="Aman Singh",
                hashed_password=UNUSABLE_PASSWORD,
                role="maintenance"
            )
        ]
        db.add_all(users)
        db.commit()
        for u in users:
            db.refresh(u)
        admin_id = users[0].id
        inspector_id = users[1].id
        maintenance_id = users[2].id

        logger.info(f"Users seeded successfully. Admin ID: {admin_id}, Inspector ID: {inspector_id}, Maintenance ID: {maintenance_id}")

        # 3. Seed Distress Records (20 items)
        logger.info("Seeding 20 road distress records...")
        distress_types = ["Pothole", "Alligator Crack", "Rutting", "Edge Break", "Longitudinal Crack"]
        severities = ["critical", "high", "medium", "low"]
        statuses = ["detected", "scheduled", "in_progress", "completed", "verified"]
        
        # Coordinates mapped around NH-48 and major corridors
        locations = [
            (18.7501, 73.4002, "Lonavala Ghats NH-48"),
            (18.5912, 73.7123, "Hinjewadi Phase 3 Road"),
            (19.0824, 72.9135, "Ghatkopar Flyover Eastern Express"),
            (19.2015, 73.0112, "Thane Toll Plaza Corridor"),
            (13.1042, 77.3821, "Nelamangala Highway NH-48"),
            (12.8915, 77.4812, "Kengeri Metro Corridor SH-17"),
            (12.5231, 76.9015, "Mandya Bypass NH-275"),
            (15.3614, 75.1213, "Davangere Highway Corridor"),
            (28.5612, 77.2145, "Ring Road AIIMS Underpass"),
            (28.6315, 77.2212, "CP Outer Circle G-Block"),
            (28.5942, 77.1712, "Dhaula Kuan Flyover Loop"),
            (12.9214, 80.1215, "Tambaram-Chengalpattu Flyover"),
            (9.9215, 78.1142, "Villupuram Bypass NH-45"),
            (13.0712, 80.2014, "Koyambedu Junction Flyover"),
            (12.4415, 79.8312, "Melmaruvathur Toll Sector"),
            (18.9612, 72.8214, "Haji Ali Outer Circle"),
            (19.0512, 72.8314, "Bandra Worli Sea Link Tollway"),
            (28.5215, 77.2614, "Jasola Vihar Main Flyover"),
            (13.0142, 80.2215, "Guindy Industrial Estate Entrance"),
            (12.9712, 77.5914, "MG Road Metro Pillar 110")
        ]

        distresses = []
        now = datetime.now()
        for i, loc in enumerate(locations):
            dtype = distress_types[i % len(distress_types)]
            sev = severities[i % len(severities)]
            # Force higher distress status diversity
            st = statuses[i % len(statuses)]
            conf = 0.75 + (i * 0.011) % 0.23
            
            # Detected date spread over last 15 days
            detected_date = now - timedelta(days=15 - i)
            
            d = RoadDistress(
                distress_type=dtype,
                severity=sev,
                confidence_score=round(conf, 2),
                latitude=loc[0],
                longitude=loc[1],
                image_url=f"http://example.com/images/distress_{i+1}.jpg",
                status=st,
                detected_at=detected_date,
                created_at=detected_date,
                updated_at=detected_date
            )
            distresses.append(d)

        db.add_all(distresses)
        db.commit()
        for d in distresses:
            db.refresh(d)
        
        logger.info("Distress records seeded successfully.")

        # 4. Seed Uploaded Videos (10 items)
        logger.info("Seeding 10 uploaded video logs...")
        video_statuses = ["completed", "processing", "pending", "failed"]
        videos = []
        for i in range(10):
            vname = f"surveillance_feed_corridor_0{i+1}.mp4"
            v = UploadedVideo(
                filename=vname,
                filepath=f"uploads/videos/{vname}",
                processing_status=video_statuses[i % len(video_statuses)],
                uploader_id=inspector_id if i % 2 == 0 else admin_id,
                upload_timestamp=now - timedelta(days=10 - i),
                created_at=now - timedelta(days=10 - i),
                updated_at=now - timedelta(days=10 - i)
            )
            videos.append(v)
        db.add_all(videos)
        db.commit()
        logger.info("Video logs seeded successfully.")

        # 5. Seed Maintenance Tasks (15 items)
        logger.info("Seeding 15 maintenance scheduling tasks...")
        tasks = []
        # Assign maintenance tasks linked to first 15 distress records
        for i in range(15):
            distress_id = distresses[i].id
            priority = "high" if distresses[i].severity in ["critical", "high"] else "medium"
            due_date = now + timedelta(days=i + 1)
            
            t = MaintenanceTask(
                distress_id=distress_id,
                recommendation=f"Execute standard anomaly repair routine for logged distress code DIS-00{distress_id}.",
                priority=priority,
                assigned_to=maintenance_id if i % 2 == 0 else admin_id,
                due_date=due_date,
                status="scheduled" if i % 3 != 0 else "in_progress",
                created_at=now - timedelta(days=5),
                updated_at=now - timedelta(days=5)
            )
            tasks.append(t)
        db.add_all(tasks)
        db.commit()
        logger.info("Maintenance tasks seeded successfully.")

        # 6. Seed Reports (10 items)
        logger.info("Seeding 10 generated report logs...")
        report_types = ["PDF", "CSV", "JSON"]
        reports = []
        for i in range(10):
            r = Report(
                report_name=f"NH-Corridor_{i+1}_Severity_Summary",
                report_type=report_types[i % len(report_types)],
                generated_by=admin_id if i % 2 == 0 else inspector_id,
                generated_at=now - timedelta(days=12 - i),
                created_at=now - timedelta(days=12 - i),
                updated_at=now - timedelta(days=12 - i)
            )
            reports.append(r)
        db.add_all(reports)
        db.commit()
        logger.info("Report logs seeded successfully.")
        
        logger.info("--- DATABASE SEEDING COMPLETED SUCCESSFULLY ---")

    except Exception as e:
        logger.critical(f"Database seeding failed: {e}")
        db.rollback()
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()
