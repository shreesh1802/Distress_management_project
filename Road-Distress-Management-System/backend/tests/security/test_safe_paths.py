"""
Path confinement (ATK-004): unit tests for app.core.safe_paths plus end-to-end checks that a
database-stored path can never make the API read or delete a file outside uploads/ or reports/.
"""

import os

import pytest

from app.core import safe_paths
from app.core.safe_paths import resolve_stored_path, sanitize_file_name
from app.models.report import Report
from app.models.video import UploadedVideo


# ----------------------------------------------------------------------------- unit tests
@pytest.fixture()
def roots(tmp_path):
    base = tmp_path / "base"
    uploads = base / "uploads"
    (uploads / "videos").mkdir(parents=True)
    (uploads / "videos" / "ok.mp4").write_bytes(b"x")
    secret = base / "secret.txt"
    secret.write_text("top secret")
    outside = tmp_path / "outside.txt"
    outside.write_text("outside")
    return {"base": str(base), "uploads": str(uploads), "secret": secret, "outside": outside, "tmp": tmp_path}


def resolve(roots, stored):
    return resolve_stored_path(stored, roots["base"], [roots["uploads"]])


def test_valid_relative_path_resolves(roots):
    assert resolve(roots, "uploads/videos/ok.mp4") == os.path.realpath(os.path.join(roots["uploads"], "videos", "ok.mp4"))


def test_nonexistent_path_inside_root_still_resolves(roots):
    assert resolve(roots, "uploads/videos/not-yet-created.mp4") is not None


def test_query_suffix_is_stripped(roots):
    assert resolve(roots, "uploads/videos/ok.mp4?tracks=3&x=y") == os.path.realpath(
        os.path.join(roots["uploads"], "videos", "ok.mp4")
    )


@pytest.mark.parametrize(
    "stored",
    [
        "../secret.txt",
        "uploads/../secret.txt",
        "uploads/videos/../../secret.txt",
        "uploads/../../outside.txt",
        "../../../../../../../../etc/passwd",
        "uploads/videos/../../../outside.txt",
    ],
)
def test_parent_traversal_is_rejected(roots, stored):
    assert resolve(roots, stored) is None


@pytest.mark.parametrize(
    "stored",
    [
        "..\\secret.txt",
        "uploads\\..\\secret.txt",
        "uploads\\videos\\..\\..\\secret.txt",
        "..\\..\\Windows\\win.ini",
    ],
)
def test_windows_style_traversal_is_rejected(roots, stored):
    assert resolve(roots, stored) is None


@pytest.mark.parametrize(
    "stored",
    [
        "/etc/passwd",
        "/uploads/videos/ok.mp4",
        "C:\\Windows\\win.ini",
        "C:/Windows/win.ini",
        "c:secret.txt",
        "\\\\server\\share\\file.txt",
        "\\Windows\\win.ini",
        "//server/share/file",
    ],
)
def test_absolute_paths_are_rejected(roots, stored):
    assert resolve(roots, stored) is None


def test_absolute_path_to_a_real_file_inside_root_is_still_rejected(roots):
    # Stored values are always relative; an absolute path is never legitimate.
    assert resolve(roots, os.path.join(roots["uploads"], "videos", "ok.mp4")) is None


@pytest.mark.parametrize("stored", [None, "", "   ", "?query-only", "uploads/\x00evil", 123])
def test_empty_or_hostile_values_are_rejected(roots, stored):
    assert resolve(roots, stored) is None


def test_the_root_directory_itself_is_not_a_file_target(roots):
    assert resolve(roots, "uploads") is None
    assert resolve(roots, "uploads/") is None


def test_sibling_directory_with_common_prefix_is_rejected(roots):
    # "uploads_evil" shares a string prefix with "uploads" but is a different directory.
    (roots["tmp"] / "base" / "uploads_evil").mkdir()
    assert resolve(roots, "uploads_evil/x.mp4") is None


def test_symlink_escaping_the_root_is_rejected(roots):
    link = os.path.join(roots["uploads"], "escape")
    try:
        os.symlink(str(roots["tmp"]), link, target_is_directory=True)
    except (OSError, NotImplementedError):
        pytest.skip("symlinks not permitted on this system")
    assert resolve(roots, "uploads/escape/outside.txt") is None
    # a symlink that stays inside the root is fine
    inner = os.path.join(roots["uploads"], "inner")
    os.symlink(os.path.join(roots["uploads"], "videos"), inner, target_is_directory=True)
    assert resolve(roots, "uploads/inner/ok.mp4") is not None


def test_module_helpers_use_the_fixed_roots():
    assert safe_paths.resolve_upload_path("uploads/crops/crop_v20_1.jpg").startswith(os.path.realpath(safe_paths.UPLOADS_ROOT))
    assert safe_paths.resolve_upload_path("uploads/processed/20/processed_video.mp4") is not None
    assert safe_paths.resolve_upload_path("../.env") is None
    assert safe_paths.resolve_upload_path("uploads/../.env") is None
    assert safe_paths.resolve_report_path("reports/generated/report_video_1.pdf") is not None
    assert safe_paths.resolve_report_path("uploads/videos/x.mp4") is None
    assert safe_paths.resolve_report_path("../backend/.env") is None


@pytest.mark.parametrize(
    "raw, expected",
    [
        ("../../etc/passwd", "passwd"),
        ("..\\..\\boot.ini", "boot.ini"),
        ("a b?c*.mp4", "a_b_c_.mp4"),
        (".hidden", "hidden"),
        ("", "file"),
        (None, "file"),
        ("/", "file"),
    ],
)
def test_sanitize_file_name(raw, expected):
    assert sanitize_file_name(raw) == expected


def test_sanitize_file_name_caps_length():
    assert len(sanitize_file_name("a" * 500 + ".mp4")) <= 120


# ----------------------------------------------------------------------------- API level
def _add_video(db, filepath, processed=None, uploader_id=None):
    video = UploadedVideo(
        filename="evil.mp4", filepath=filepath, processed_filepath=processed, processed_video_path=processed,
        processing_status="completed", uploader_id=uploader_id,
    )
    db.add(video)
    db.commit()
    db.refresh(video)
    return video.id


def test_stream_raw_serves_files_inside_uploads_only(client, db, make_user, sandbox_storage):
    _, _, headers = make_user()
    good = sandbox_storage.uploads_dir / "videos" / "good.mp4"
    good.write_bytes(b"VIDEO-BYTES")
    secret = sandbox_storage.root / "secret.txt"
    secret.write_text("TOP-SECRET")

    ok_id = _add_video(db, "uploads/videos/good.mp4")
    assert client.get(f"/api/v1/videos/{ok_id}/stream-raw", headers=headers).content == b"VIDEO-BYTES"

    for hostile in ("../secret.txt", "uploads/../../secret.txt", str(secret), "..\\secret.txt", "C:\\Windows\\win.ini"):
        vid = _add_video(db, hostile)
        r = client.get(f"/api/v1/videos/{vid}/stream-raw", headers=headers)
        assert r.status_code == 404, hostile
        assert b"TOP-SECRET" not in r.content
        assert "secret" not in r.text.lower() or "not found" in r.text.lower()


def test_download_processed_is_confined(client, db, make_user, sandbox_storage):
    _, _, headers = make_user()
    secret = sandbox_storage.root / "secret.txt"
    secret.write_text("TOP-SECRET")
    vid = _add_video(db, "uploads/videos/x.mp4", processed=str(secret))
    r = client.get(f"/api/v1/videos/{vid}/download-processed", headers=headers)
    assert r.status_code == 404 and b"TOP-SECRET" not in r.content


def test_delete_video_never_removes_files_outside_uploads(client, db, make_user, sandbox_storage):
    _, _, headers = make_user()
    victim = sandbox_storage.root / "precious.txt"
    victim.write_text("do not delete")
    inside = sandbox_storage.uploads_dir / "videos" / "mine.mp4"
    inside.write_bytes(b"x")

    vid = _add_video(db, "../precious.txt", processed=str(victim))
    assert client.delete(f"/api/v1/videos/{vid}", headers=headers).status_code == 200
    assert victim.exists(), "a stored path outside uploads/ must never be deleted"

    vid2 = _add_video(db, "uploads/videos/mine.mp4")
    assert client.delete(f"/api/v1/videos/{vid2}", headers=headers).status_code == 200
    assert not inside.exists(), "legitimate uploads are still removed"


def test_legacy_upload_route_sanitises_file_name(client, make_user, db):
    uid, _, headers = make_user()
    r = client.post("/api/v1/upload/video", headers=headers,
                    json={"file_name": "../../etc/passwd", "uploaded_by": 999999})
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["file_name"] == "passwd"
    assert body["uploaded_by"] == uid  # caller, not the client-supplied id
    video = db.get(UploadedVideo, body["id"])
    assert video.filepath == "uploads/videos/passwd"
    assert ".." not in video.filepath


@pytest.mark.parametrize("field", ["filepath", "processed_filepath", "processed_video_path"])
def test_legacy_update_rejects_path_fields(client, make_user, db, field):
    _, _, headers = make_user()
    vid = _add_video(db, "uploads/videos/a.mp4")
    r = client.put(f"/api/v1/upload/video/{vid}", headers=headers, json={field: "/etc/passwd"})
    assert r.status_code == 422
    assert db.get(UploadedVideo, vid) is not None
    db.expire_all()
    assert db.get(UploadedVideo, vid).filepath == "uploads/videos/a.mp4"


def test_legacy_update_still_allows_status_changes(client, make_user, db):
    _, _, headers = make_user()
    vid = _add_video(db, "uploads/videos/a.mp4")
    r = client.put(f"/api/v1/upload/video/{vid}", headers=headers, json={"processing_status": "failed"})
    assert r.status_code == 200 and r.json()["processing_status"] == "failed"


def test_distress_create_cannot_set_server_file_references(client, make_user):
    _, _, headers = make_user()
    payload = {
        "distress_type": "pothole", "severity": "high", "confidence_score": 0.9,
        "latitude": 19.0, "longitude": 72.0,
    }
    # detection_image_path is not part of the client schema: it is ignored, never stored
    r = client.post("/api/v1/distress/", headers=headers, json={**payload, "detection_image_path": "../../../.env"})
    assert r.status_code == 201
    assert r.json()["detection_image_path"] is None
    # image_url must be a plain relative reference
    for bad in ("/etc/passwd", "../../x.jpg", "http://evil.test/x.jpg", "C:\\x.jpg"):
        assert client.post("/api/v1/distress/", headers=headers, json={**payload, "image_url": bad}).status_code == 422


def test_report_downloads_are_confined_to_reports(client, db, make_user, sandbox_storage):
    _, _, headers = make_user()
    good = sandbox_storage.reports_dir / "generated" / "good.pdf"
    good.write_bytes(b"%PDF-1.4 good")
    (sandbox_storage.root / "backend" / "secret.env").write_text("SECRET=1")

    def add(path):
        row = Report(report_name="r", report_type="PDF", filepath=path)
        db.add(row)
        db.commit()
        db.refresh(row)
        return row.id

    ok = add("reports/generated/good.pdf")
    r = client.get(f"/api/v1/reports/download/{ok}", headers=headers)
    assert r.status_code == 200 and r.content.startswith(b"%PDF")

    for hostile in ("backend/secret.env", "../backend/secret.env", "reports/../backend/secret.env",
                    str(sandbox_storage.root / "backend" / "secret.env")):
        rid = add(hostile)
        for route in ("download", "preview", "excel/download"):
            resp = client.get(f"/api/v1/reports/{route}/{rid}", headers=headers)
            assert resp.status_code == 404, (route, hostile)
            assert b"SECRET" not in resp.content
