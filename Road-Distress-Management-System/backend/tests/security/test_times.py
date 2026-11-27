"""
Times: the API always sends UTC with its offset (so the app can show local time), and text the server
writes for people -- report headers, live session names, field-note times -- is in REPORT_TIMEZONE (IST).
"""

from datetime import datetime, timedelta, timezone

from app.core import timezones as tz
from app.models.video import UploadedVideo


def test_report_zone_defaults_to_india_and_unknown_names_fall_back_to_utc():
    ist = tz.load_report_zone("Asia/Kolkata")
    assert datetime(2026, 11, 27, 20, 30, tzinfo=timezone.utc).astimezone(ist).strftime("%H:%M") == "02:00"
    assert tz.load_report_zone("Not/AZone").utcoffset(None) == timedelta(0)


def test_a_utc_time_is_written_in_ist_for_reports(monkeypatch):
    monkeypatch.setattr(tz, "REPORT_ZONE", tz.load_report_zone("Asia/Kolkata"))
    utc = datetime(2026, 11, 27, 20, 30, 15, tzinfo=timezone.utc)   # 2:00:15 am in India the next day
    assert tz.format_report_time(utc) == "2026-11-28 02:00:15 IST"
    # a naive value is UTC as stored by this app
    assert tz.format_report_time(utc.replace(tzinfo=None), "%d %b %Y %H:%M", with_zone=False) == "28 Nov 2026 02:00"
    assert tz.format_report_time(None) == ""


def test_times_read_back_from_the_database_are_marked_utc(db):
    video = UploadedVideo(filename="clock test", filepath=None, processing_status="completed",
                          upload_timestamp=datetime(2026, 11, 27, 20, 30))
    db.add(video)
    db.commit()
    db.expire_all()
    loaded = db.query(UploadedVideo).filter(UploadedVideo.id == video.id).one()
    assert loaded.upload_timestamp.tzinfo is not None
    assert loaded.upload_timestamp == datetime(2026, 11, 27, 20, 30, tzinfo=timezone.utc)
    assert loaded not in db.dirty, "marking a time as UTC must not count as a change to save"


def test_the_api_sends_times_with_their_utc_offset(client, make_user, db):
    _, _, headers = make_user()
    video = UploadedVideo(filename="Live session test", filepath=None, processing_status="completed",
                          processing_stage="Live session", upload_timestamp=datetime(2026, 11, 27, 20, 30))
    db.add(video)
    db.commit()
    sessions = client.get("/api/v1/live/sessions", headers=headers).json()
    started = next(s["started_at"] for s in sessions if s["id"] == video.id)
    assert started.endswith("+00:00") or started.endswith("Z"), started
    assert datetime.fromisoformat(started.replace("Z", "+00:00")) == datetime(2026, 11, 27, 20, 30, tzinfo=timezone.utc)


def test_a_new_live_session_is_named_in_report_time(monkeypatch, db):
    from app.services.live import live_camera_service as svc

    monkeypatch.setattr(tz, "REPORT_ZONE", tz.load_report_zone("Asia/Kolkata"))
    monkeypatch.setattr(svc, "utc_now", lambda: datetime(2026, 11, 27, 20, 30, tzinfo=timezone.utc))
    manager = svc.LiveCameraManager()
    video_id = manager.ensure_session_video(db)
    assert db.get(UploadedVideo, video_id).filename == "Live session 2026-11-28 02:00 IST"
