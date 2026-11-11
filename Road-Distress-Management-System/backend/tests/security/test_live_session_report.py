"""
Live sessions are filed under one uploaded_videos row so their detections can be turned into a report.
"""

import numpy as np
import pytest

from app.models.distress import RoadDistress
from app.models.video import UploadedVideo
from app.services.live import live_config as cfg
from app.services.live.live_camera_service import LiveCameraManager


@pytest.fixture()
def manager(tmp_path, monkeypatch):
    monkeypatch.setattr(cfg, "SNAPSHOT_DIR", str(tmp_path / "snapshots"))
    monkeypatch.setattr(cfg, "BACKEND_ROOT", str(tmp_path))
    monkeypatch.setattr(cfg, "PERSIST_MIN_INTERVAL_SEC", 0.0)
    monkeypatch.setattr(cfg, "PERSIST_CONF_THRESH", 0.1)
    m = LiveCameraManager()
    m._reset_session_state("usb", 30.1, 76.1)
    return m


def _det(name="pothole", source="road", conf=0.9):
    return {"class_name": name, "model_source": source, "confidence": conf}


def _persist(manager, det, frame_no=1, elapsed=2.5):
    manager._maybe_persist(det, "high", np.zeros((32, 32, 3), dtype="uint8"), frame_no, elapsed, 30.1, 76.1)


def test_no_session_record_until_something_is_saved(manager, client):
    assert manager.status()["session_video_id"] is None
    assert manager._session_video_id is None


def test_first_saved_detection_creates_one_session_record(manager, client, db):
    _persist(manager, _det("pothole"))
    _persist(manager, _det("alligator_crack"), frame_no=2, elapsed=4.0)
    _persist(manager, _det("TRAFFIC SIGN", source="signage"), frame_no=3, elapsed=6.0)

    video_id = manager.status()["session_video_id"]
    assert isinstance(video_id, int)

    db.expire_all()
    video = db.get(UploadedVideo, video_id)
    assert video.filename.startswith("Live session ")
    assert video.processing_status == "completed"
    assert video.filepath is None
    assert video.processing_duration == 6.0  # follows the session length

    rows = db.query(RoadDistress).filter(RoadDistress.video_id == video_id).all()
    assert {r.distress_type for r in rows} == {"pothole", "alligator_crack", "TRAFFIC SIGN"}
    assert all(r.source_type == "live" for r in rows)
    assert db.query(UploadedVideo).filter(UploadedVideo.filename.like("Live session %")).count() >= 1


def test_a_new_session_gets_its_own_record(manager, client, db):
    _persist(manager, _det("pothole"))
    first = manager.status()["session_video_id"]

    manager._reset_session_state("usb", None, None)  # what start() does
    assert manager.status()["session_video_id"] is None
    _persist(manager, _det("pothole"))
    second = manager.status()["session_video_id"]

    assert second is not None and second != first


def test_low_confidence_detections_create_nothing(manager, client, db):
    before = db.query(UploadedVideo).count()
    _persist(manager, _det(conf=0.05))
    assert manager.status()["session_video_id"] is None
    assert db.query(UploadedVideo).count() == before


def test_session_appears_in_the_video_list_for_reports(manager, client, admin):
    _uid, _email, headers = admin
    _persist(manager, _det("pothole"))
    video_id = manager.status()["session_video_id"]
    listed = client.get("/api/v1/videos/", headers=headers, params={"skip": 0, "limit": 500})
    assert listed.status_code == 200
    ids = {v["id"] for v in listed.json()}
    assert video_id in ids
