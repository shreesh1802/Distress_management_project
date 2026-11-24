"""History needs to find past live sessions: GET /live/sessions."""

from app.models.distress import RoadDistress
from app.models.observation import SessionObservation
from app.models.video import UploadedVideo


def _session(db, name, duration=None):
    video = UploadedVideo(filename=name, filepath=None, processing_status="completed",
                          processing_stage="Live session", progress=100, processing_duration=duration)
    db.add(video)
    db.commit()
    db.refresh(video)
    return video


def _detection(db, video_id, severity):
    db.add(RoadDistress(video_id=video_id, distress_type="pothole", severity=severity, confidence_score=0.9,
                        latitude=1.0, longitude=2.0, status="detected", source_type="live"))
    db.commit()


def _note(db, video_id):
    db.add(SessionObservation(video_id=video_id, note="n", transcript_status="none"))
    db.commit()


def test_it_needs_a_signed_in_user(client):
    assert client.get("/api/v1/live/sessions").status_code == 401


def test_it_lists_live_sessions_newest_first_with_real_counts(client, make_user, db):
    _, _, headers = make_user()
    first = _session(db, "Live session 2026-11-01 10:00 UTC", duration=61.5)
    second = _session(db, "Live session 2026-11-02 09:00 UTC", duration=12.0)
    for severity in ("high", "critical", "medium", "low", "High"):
        _detection(db, first.id, severity)
    _note(db, first.id)
    _note(db, first.id)
    _detection(db, second.id, "low")

    sessions = client.get("/api/v1/live/sessions", headers=headers).json()
    ours = [s for s in sessions if s["id"] in (first.id, second.id)]
    assert [s["id"] for s in ours] == [second.id, first.id], "newest first"

    older = ours[1]
    assert older["name"] == "Live session 2026-11-01 10:00 UTC"
    assert older["duration_seconds"] == 61.5
    assert older["detection_count"] == 5 and older["serious_count"] == 3   # high, critical, High
    assert older["field_note_count"] == 2
    newer = ours[0]
    assert newer["detection_count"] == 1 and newer["serious_count"] == 0 and newer["field_note_count"] == 0


def test_only_live_sessions_are_listed_not_uploaded_videos(client, make_user, db):
    _, _, headers = make_user()
    upload = UploadedVideo(filename="road_survey.mp4", filepath="uploads/videos/a.mp4",
                           processing_status="completed", processing_stage="Idle")
    db.add(upload)
    db.commit()
    db.refresh(upload)
    ids = [s["id"] for s in client.get("/api/v1/live/sessions", headers=headers).json()]
    assert upload.id not in ids


def test_the_limit_is_validated(client, make_user):
    _, _, headers = make_user()
    assert client.get("/api/v1/live/sessions", params={"limit": 0}, headers=headers).status_code == 422
    assert client.get("/api/v1/live/sessions", params={"limit": 201}, headers=headers).status_code == 422
