"""
Field notes: snapshots and voice notes a surveyor adds by hand to a live session's report.
Covers who may add / read them, validation of what is uploaded, the files on disk, the PDF / Excel sections
and clean-up (deleting a note, a report or an account).
"""

import io
import os

import numpy as np
import pytest

from app.api.v1.routes import observations as obs_routes
from app.models.observation import SessionObservation
from app.models.video import UploadedVideo
from app.services import observation_service as svc
from app.services.live.live_camera_service import LiveCameraManager

WEBM = b"\x1a\x45\xdf\xa3" + b"\x00" * 64          # the container is not sniffed; any bytes pass the extension rule
WAV = b"RIFF\x24\x00\x00\x00WAVEfmt " + b"\x00" * 32


class FakeManager:
    """Stands in for the live camera singleton: a running session with one camera picture."""

    def __init__(self, db_factory):
        self.running = True
        self.frame = np.full((48, 64, 3), 128, dtype="uint8")
        self.video_id = None

    def is_running(self):
        return self.running

    def snapshot_frame(self):
        return None if self.frame is None else self.frame.copy()

    def session_location(self):
        return 30.3398, 76.3869

    def ensure_session_video(self, db):
        if self.video_id is None:
            video = UploadedVideo(filename="Live session test", filepath=None, processing_status="completed")
            db.add(video)
            db.commit()
            db.refresh(video)
            self.video_id = video.id
        return self.video_id


@pytest.fixture()
def notes_env(sandbox_storage, monkeypatch):
    """A running fake live session, with every field-note file written to a throw-away folder."""
    backend = sandbox_storage.backend_dir
    monkeypatch.setattr(svc, "BASE_DIR", str(backend))
    monkeypatch.setattr(svc, "IMAGE_DIR", str(backend / "uploads" / "observations" / "images"))
    monkeypatch.setattr(svc, "AUDIO_DIR", str(backend / "uploads" / "observations" / "audio"))
    manager = FakeManager(None)
    monkeypatch.setattr(LiveCameraManager, "instance", classmethod(lambda cls: manager))
    transcribed = []
    monkeypatch.setattr(svc, "run_transcription_job", lambda obs_id: transcribed.append(obs_id))
    manager.transcribed = transcribed
    manager.sandbox = sandbox_storage
    return manager


def _audio(name="note.webm", data=WEBM):
    return {"file": (name, io.BytesIO(data), "application/octet-stream")}


def _stored(sandbox, relative):
    return sandbox.backend_dir / relative


# ------------------------------------------------------------------------------------------- who may use it
def test_every_route_needs_a_signed_in_user(client, notes_env):
    assert client.post("/api/v1/observations/live", data={"snapshot": "true"}).status_code == 401
    assert client.get("/api/v1/observations", params={"video_id": 1}).status_code == 401
    assert client.delete("/api/v1/observations/1").status_code == 401
    assert client.get("/api/v1/observations/1/image").status_code == 401
    assert client.get("/api/v1/observations/1/audio").status_code == 401


def test_a_note_needs_a_running_session(client, make_user, notes_env):
    _, _, headers = make_user()
    notes_env.running = False
    r = client.post("/api/v1/observations/live", data={"snapshot": "true"}, headers=headers)
    assert r.status_code == 409 and "Start live detection" in r.json()["detail"]


def test_a_note_needs_something_in_it(client, make_user, notes_env):
    _, _, headers = make_user()
    assert client.post("/api/v1/observations/live", data={}, headers=headers).status_code == 400
    assert client.post("/api/v1/observations/live", data={"note": "   "}, headers=headers).status_code == 400
    too_long = client.post("/api/v1/observations/live", data={"note": "x" * (svc.MAX_NOTE_CHARS + 1)}, headers=headers)
    assert too_long.status_code == 422


def test_a_snapshot_before_any_camera_picture_is_refused_politely(client, make_user, notes_env):
    _, _, headers = make_user()
    notes_env.frame = None
    r = client.post("/api/v1/observations/live", data={"snapshot": "true"}, headers=headers)
    assert r.status_code == 409 and "camera picture" in r.json()["detail"]


# ------------------------------------------------------------------------------------------- snapshots
def test_a_snapshot_is_saved_with_the_session_and_can_be_opened(client, make_user, notes_env, db):
    user_id, _, headers = make_user()
    r = client.post("/api/v1/observations/live", data={"snapshot": "true", "note": "Edge failure here"}, headers=headers)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["has_image"] and not body["has_audio"] and body["note"] == "Edge failure here"
    assert body["video_id"] == notes_env.video_id
    assert body["latitude"] == pytest.approx(30.3398)
    assert "uploads" not in r.text and "observations/images" not in r.text       # no filesystem paths in the answer

    db.expire_all()
    row = db.get(SessionObservation, body["id"])
    assert row.created_by_id == user_id and row.transcript_status == "none"
    assert _stored(notes_env.sandbox, row.image_path).read_bytes().startswith(b"\xff\xd8\xff")

    # a signed link works with no token; a bearer token works with no link
    assert client.get(body["image_url"]).status_code == 200
    assert client.get(body["image_url"]).headers["content-type"] == "image/jpeg"
    assert client.get(f"/api/v1/observations/{body['id']}/image", headers=headers).status_code == 200


def test_signed_links_cannot_be_reused_for_another_note_or_another_file(client, make_user, notes_env):
    _, _, headers = make_user()
    a = client.post("/api/v1/observations/live", data={"snapshot": "true"}, headers=headers).json()
    b = client.post("/api/v1/observations/live", data={"snapshot": "true"}, headers=headers).json()
    token_a = a["image_url"].split("?t=")[1]
    assert client.get(f"/api/v1/observations/{b['id']}/image", params={"t": token_a}).status_code == 401
    assert client.get(f"/api/v1/observations/{a['id']}/audio", params={"t": token_a}).status_code == 401
    assert client.get(f"/api/v1/observations/{a['id']}/image", params={"t": token_a + "0"}).status_code == 401
    assert client.get(f"/api/v1/observations/{a['id']}/image", params={"t": "1.abc"}).status_code == 401


# ------------------------------------------------------------------------------------------- voice notes
def test_a_voice_note_is_saved_and_transcribed_in_the_background(client, make_user, notes_env, db):
    _, _, headers = make_user()
    r = client.post("/api/v1/observations/live", headers=headers, data={"audio_duration_seconds": "7.5"}, files=_audio())
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["has_audio"] and not body["has_image"]
    assert body["audio_duration_seconds"] == 7.5 and body["transcript_status"] == "pending"
    assert notes_env.transcribed == [body["id"]]
    assert client.get(body["audio_url"]).status_code == 200
    assert client.get(body["audio_url"]).headers["content-type"] == "audio/webm"
    row = db.get(SessionObservation, body["id"])
    assert _stored(notes_env.sandbox, row.audio_path).read_bytes() == WEBM


@pytest.mark.parametrize("name,data,code", [
    ("note.exe", WEBM, 400),                 # not an audio format we accept
    ("note.wav", b"not really a wav file at all", 400),   # contents do not match the extension
    ("note.webm", b"", 400),                 # empty
])
def test_bad_voice_notes_are_refused_and_leave_nothing_behind(client, make_user, notes_env, name, data, code):
    _, _, headers = make_user()
    r = client.post("/api/v1/observations/live", headers=headers, data={"snapshot": "true"}, files=_audio(name, data))
    assert r.status_code == code, r.text
    assert not list((notes_env.sandbox.backend_dir / "uploads" / "observations").rglob("*.*")), \
        "a refused note must not leave its snapshot or recording on disk"


def test_oversize_voice_notes_are_refused(client, make_user, notes_env, monkeypatch):
    _, _, headers = make_user()
    monkeypatch.setattr(svc, "MAX_AUDIO_BYTES", 1000)
    r = client.post("/api/v1/observations/live", headers=headers, files=_audio(data=WEBM + b"\x00" * 2000))
    assert r.status_code == 413


def test_a_wav_with_a_real_header_is_accepted(client, make_user, notes_env):
    _, _, headers = make_user()
    assert client.post("/api/v1/observations/live", headers=headers, files=_audio("n.wav", WAV)).status_code == 201


def test_a_session_has_a_limit_on_notes(client, make_user, notes_env, monkeypatch):
    _, _, headers = make_user()
    monkeypatch.setattr(svc, "MAX_NOTES_PER_SESSION", 2)
    for _ in range(2):
        assert client.post("/api/v1/observations/live", data={"note": "x"}, headers=headers).status_code == 201
    assert client.post("/api/v1/observations/live", data={"note": "x"}, headers=headers).status_code == 409


# ------------------------------------------------------------------------------------------- listing / deleting
def test_notes_are_listed_oldest_first_and_can_be_deleted_with_their_files(client, make_user, notes_env, db):
    _, _, headers = make_user()
    first = client.post("/api/v1/observations/live", data={"note": "first"}, headers=headers).json()
    second = client.post("/api/v1/observations/live", data={"snapshot": "true"}, headers=headers).json()

    listed = client.get("/api/v1/observations", params={"video_id": notes_env.video_id}, headers=headers).json()
    assert [n["id"] for n in listed] == [first["id"], second["id"]]
    assert client.get("/api/v1/observations", params={"video_id": 0}, headers=headers).status_code == 422

    image = _stored(notes_env.sandbox, db.get(SessionObservation, second["id"]).image_path)
    assert image.exists()
    assert client.delete(f"/api/v1/observations/{second['id']}", headers=headers).status_code == 204
    assert not image.exists()
    assert client.delete(f"/api/v1/observations/{second['id']}", headers=headers).status_code == 404


def test_a_stored_path_outside_uploads_is_never_served_or_deleted(client, make_user, notes_env, db):
    _, _, headers = make_user()
    secret = notes_env.sandbox.root / "secret.jpg"
    secret.write_bytes(b"\xff\xd8\xff secret")
    video_id = notes_env.ensure_session_video(db)
    row = SessionObservation(video_id=video_id, image_path="../../secret.jpg", transcript_status="none")
    db.add(row)
    db.commit()
    assert client.get(f"/api/v1/observations/{row.id}/image", headers=headers).status_code == 404
    client.delete(f"/api/v1/observations/{row.id}", headers=headers)
    assert secret.exists()


def test_deleting_a_report_removes_its_notes_and_files(db, notes_env):
    from app.services.video import remove_video
    video_id = notes_env.ensure_session_video(db)
    image = svc.save_snapshot(notes_env.snapshot_frame())
    svc.create_observation(db, video_id=video_id, user_id=None, note="n", image_path=image, audio_path=None,
                           audio_filename=None, audio_duration_seconds=None, latitude=None, longitude=None)
    path = _stored(notes_env.sandbox, image)
    assert path.exists()
    remove_video(db, video_id)
    assert db.query(SessionObservation).filter(SessionObservation.video_id == video_id).count() == 0
    assert not path.exists()


def test_deleting_an_account_keeps_the_notes_without_the_person(db, notes_env, make_user):
    from app.models.user import User
    from app.services.account_deletion import delete_account
    user_id, _, _ = make_user()
    video_id = notes_env.ensure_session_video(db)
    obs = svc.create_observation(db, video_id=video_id, user_id=user_id, note="keep me", image_path=None,
                                 audio_path=None, audio_filename=None, audio_duration_seconds=None,
                                 latitude=None, longitude=None)
    delete_account(db, db.get(User, user_id))
    db.expire_all()
    kept = db.get(SessionObservation, obs.id)
    assert kept is not None and kept.created_by_id is None and kept.note == "keep me"


# ------------------------------------------------------------------------------------------- the report
def _make_note(db, notes_env, **kw):
    video_id = notes_env.ensure_session_video(db)
    defaults = dict(video_id=video_id, user_id=None, note=None, image_path=None, audio_path=None, audio_filename=None,
                    audio_duration_seconds=None, latitude=30.1, longitude=76.2)
    defaults.update(kw)
    return video_id, svc.create_observation(db, **defaults)


@pytest.fixture()
def excel_out(monkeypatch, tmp_path):
    """Makes the Excel generator save into a temp folder (it computes its own output path) and returns it."""
    from openpyxl.workbook.workbook import Workbook
    original = Workbook.save
    target = tmp_path / "out.xlsx"
    monkeypatch.setattr(Workbook, "save", lambda self, filename: original(self, str(target)))
    return target


def test_pdf_section_is_empty_without_notes_and_lists_them_with_notes(db, notes_env):
    from app.services.field_notes_report import field_notes_flowables
    video_id = notes_env.ensure_session_video(db)
    assert field_notes_flowables(db, video_id) == []

    image = svc.save_snapshot(notes_env.snapshot_frame())
    _make_note(db, notes_env, note="Edge <b>failure</b> & potholes", image_path=image)
    flow = field_notes_flowables(db, video_id)
    text = " ".join(getattr(f, "text", "") or "" for f in flow)
    assert "Surveyor Field Notes" in text
    assert any(type(part).__name__ == "KeepTogether" for part in flow)


def test_full_pdf_and_excel_include_the_notes_and_survive_hostile_text(db, notes_env, monkeypatch, tmp_path, excel_out):
    from openpyxl import load_workbook
    from app.services import excel_generator, pdf_generator

    image = svc.save_snapshot(notes_env.snapshot_frame())
    video_id, obs = _make_note(db, notes_env, note="=HYPERLINK(\"http://evil\",\"x\") <b>unclosed", image_path=image)
    obs.transcript, obs.transcript_status, obs.audio_path = "+1+1 spoken <i>words", "done", "uploads/observations/audio/x.webm"
    db.commit()

    original = pdf_generator.SimpleDocTemplate
    out = tmp_path / "out.pdf"
    monkeypatch.setattr(pdf_generator, "SimpleDocTemplate", lambda path, **kw: original(str(out), **kw))
    assert pdf_generator.generate_video_pdf_report(db, video_id).startswith("reports/generated/")
    assert out.read_bytes().startswith(b"%PDF")

    excel_generator.generate_video_excel_report(db, video_id)
    workbook = load_workbook(excel_out)
    assert "Field Notes" in workbook.sheetnames
    sheet = workbook["Field Notes"]
    cells = [c.value for row in sheet.iter_rows(min_row=5, max_row=5) for c in row]
    assert not any(isinstance(v, str) and v[:1] in "=+-@" for v in cells), "typed / spoken text must never be a formula"
    assert any(isinstance(v, str) and "HYPERLINK" in v for v in cells)


def test_reports_without_notes_have_no_field_notes_sheet(db, notes_env, excel_out):
    from openpyxl import load_workbook
    from app.services import excel_generator
    video_id = notes_env.ensure_session_video(db)
    excel_generator.generate_video_excel_report(db, video_id)
    assert "Field Notes" not in load_workbook(excel_out).sheetnames


def test_a_problem_reading_the_notes_never_stops_the_main_report(db, notes_env, monkeypatch):
    from openpyxl import Workbook
    from app.services import field_notes_report as fnr

    def broken(*args, **kwargs):
        raise RuntimeError("the notes table is not there")

    monkeypatch.setattr(fnr, "list_for_video", broken)
    assert fnr.field_notes_flowables(db, 1) == []
    assert fnr.add_field_notes_sheet(Workbook(), db, 1) is None


def test_voice_notes_can_be_played_in_a_browser_that_asks_for_byte_ranges(client, make_user, notes_env):
    """Safari (and every browser's audio player) asks for pieces of the file with a Range header."""
    _, _, headers = make_user()
    data = b"\x00\x00\x00\x18ftypM4A " + bytes(range(256)) * 4
    body = client.post("/api/v1/observations/live", headers=headers, files=_audio("n.m4a", data)).json()
    origin = {"Origin": "https://phone-test.road-inspection-web.pages.dev"}

    whole = client.get(body["audio_url"], headers=origin)
    assert whole.status_code == 200 and whole.headers["accept-ranges"] == "bytes"
    assert whole.headers["content-type"] == "audio/mp4"
    assert whole.headers["access-control-allow-origin"] in ("*", origin["Origin"])   # <audio crossorigin> needs it

    first = client.get(body["audio_url"], headers={"Range": "bytes=0-1", **origin})
    assert first.status_code == 206 and first.content == data[:2]
    assert first.headers["content-range"] == f"bytes 0-1/{len(data)}"
    tail = client.get(body["audio_url"], headers={"Range": f"bytes={len(data) - 10}-", **origin})
    assert tail.status_code == 206 and tail.content == data[-10:]
