"""
Signed report links, response security headers, generic error messages, CORS, PDF/Excel injection,
input constraints on the legacy schemas.
"""

import time

import pytest

from app.core.config import settings
from app.models.report import Report
from app.models.video import UploadedVideo
from app.models.distress import RoadDistress
from app.services import download_links
from app.services.download_links import sign_download_token, verify_download_token


# ----------------------------------------------------------------------------- signed links
@pytest.fixture()
def report(db, sandbox_storage):
    (sandbox_storage.reports_dir / "generated" / "r1.pdf").write_bytes(b"%PDF-1.4 report one")
    (sandbox_storage.reports_dir / "excel" / "r1.xlsx").write_bytes(b"PK\x03\x04 sheet")
    pdf = Report(report_name="p", report_type="PDF", filepath="reports/generated/r1.pdf")
    xls = Report(report_name="x", report_type="EXCEL", filepath="reports/excel/r1.xlsx")
    db.add_all([pdf, xls])
    db.commit()
    db.refresh(pdf)
    db.refresh(xls)
    return pdf.id, xls.id


def test_download_routes_need_a_bearer_token_or_a_signed_link(client, report):
    pdf_id, xls_id = report
    for path in (f"/api/v1/reports/download/{pdf_id}", f"/api/v1/reports/preview/{pdf_id}",
                 f"/api/v1/reports/excel/download/{xls_id}"):
        assert client.get(path).status_code == 401
        assert client.get(path + "?t=garbage").status_code == 401
        assert client.get(path + "?t=9999999999.deadbeef").status_code == 401


def test_link_minting_requires_authentication(client, report):
    pdf_id, _ = report
    assert client.post(f"/api/v1/reports/{pdf_id}/download-link").status_code == 401


def test_signed_link_roundtrip_for_every_kind(client, make_user, report):
    pdf_id, xls_id = report
    _, _, headers = make_user()
    cases = [("pdf", pdf_id, b"%PDF-1.4 report one", "application/pdf"),
             ("preview", pdf_id, b"%PDF-1.4 report one", "application/pdf"),
             ("excel", xls_id, b"PK\x03\x04 sheet", "spreadsheetml")]
    for kind, rid, expected, media in cases:
        minted = client.post(f"/api/v1/reports/{rid}/download-link?kind={kind}", headers=headers)
        assert minted.status_code == 200, minted.text
        assert minted.json()["expires_in"] == 300
        path = minted.json()["path"]
        assert path.startswith("/api/v1/reports/") and "?t=" in path
        got = client.get(path)  # NO Authorization header: this is what launchUrl does
        assert got.status_code == 200 and got.content == expected and media in got.headers["content-type"]


def test_bearer_token_alone_also_works(client, make_user, report):
    pdf_id, _ = report
    _, _, headers = make_user()
    assert client.get(f"/api/v1/reports/download/{pdf_id}", headers=headers).status_code == 200


def test_signed_link_is_bound_to_report_and_purpose(client, report):
    pdf_id, xls_id = report
    token = sign_download_token("pdf", pdf_id)
    assert client.get(f"/api/v1/reports/download/{pdf_id}?t={token}").status_code == 200
    assert client.get(f"/api/v1/reports/download/{xls_id}?t={token}").status_code == 401   # other report
    assert client.get(f"/api/v1/reports/preview/{pdf_id}?t={token}").status_code == 401    # other purpose
    assert client.get(f"/api/v1/reports/excel/download/{pdf_id}?t={token}").status_code == 401


def test_signed_link_expires_and_cannot_be_tampered_with(client, report, monkeypatch):
    pdf_id, _ = report
    token = sign_download_token("pdf", pdf_id, ttl_seconds=60)
    expiry, mac = token.split(".")
    # extending the expiry invalidates the MAC
    assert not verify_download_token(f"{int(expiry) + 9999}.{mac}", "pdf", pdf_id)
    assert not verify_download_token(f"{expiry}.{mac[:-1]}0" if mac[-1] != "0" else f"{expiry}.{mac[:-1]}1", "pdf", pdf_id)
    # expiry in the past
    real_time = time.time
    monkeypatch.setattr(download_links.time, "time", lambda: real_time() + 3600)
    assert client.get(f"/api/v1/reports/download/{pdf_id}?t={token}").status_code == 401


def test_signed_link_secret_comes_from_configuration(report, monkeypatch):
    pdf_id, _ = report
    monkeypatch.setattr(settings, "DOWNLOAD_SIGNING_SECRET", "a" * 48)
    token = sign_download_token("pdf", pdf_id)
    assert verify_download_token(token, "pdf", pdf_id)
    monkeypatch.setattr(settings, "DOWNLOAD_SIGNING_SECRET", "b" * 48)
    assert not verify_download_token(token, "pdf", pdf_id)


def test_download_error_messages_do_not_leak_paths(client, make_user, db, sandbox_storage):
    _, _, headers = make_user()
    row = Report(report_name="gone", report_type="PDF", filepath="reports/generated/missing.pdf")
    db.add(row)
    db.commit()
    db.refresh(row)
    r = client.get(f"/api/v1/reports/download/{row.id}", headers=headers)
    assert r.status_code == 404 and "missing.pdf" not in r.text and "reports/" not in r.text


# ----------------------------------------------------------------------------- headers / errors / CORS
def test_security_headers_on_api_and_other_responses(client, make_user):
    _, _, headers = make_user()
    api = client.get("/api/v1/auth/me", headers=headers)
    assert api.headers["x-content-type-options"] == "nosniff"
    assert api.headers["x-frame-options"] == "DENY"
    assert api.headers["referrer-policy"] == "no-referrer"
    assert api.headers["cache-control"] == "no-store"
    health = client.get("/health")
    assert health.headers["x-content-type-options"] == "nosniff"
    assert "no-store" not in health.headers.get("cache-control", "")  # only /api/ responses are no-store
    assert client.get("/api/v1/videos/").headers["cache-control"] == "no-store"  # also on errors


def test_health_does_not_leak_exception_details(client):
    from app.main import app
    from app.db.session import get_db

    class BrokenSession:
        bind = None

        def execute(self, *a, **k):
            raise RuntimeError("password=hunter2 host=/var/lib/secret.db")

    def broken():
        yield BrokenSession()

    app.dependency_overrides[get_db] = broken
    try:
        r = client.get("/health")
    finally:
        app.dependency_overrides.pop(get_db, None)
    assert r.status_code == 503
    assert "hunter2" not in r.text and "secret.db" not in r.text and "RuntimeError" not in r.text


def test_validation_errors_never_echo_input_and_survive_nan(client, make_user):
    _, _, headers = make_user()
    r = client.post("/api/v1/distress/", headers={**headers, "Content-Type": "application/json"},
                    content='{"distress_type":"x","severity":"high","confidence_score":NaN,"latitude":1,"longitude":1}')
    assert r.status_code == 422
    assert "input" not in r.text and isinstance(r.json()["detail"], list)


def test_cors_follows_configuration_in_development(client):
    r = client.options("/api/v1/auth/request-otp",
                       headers={"Origin": "https://evil.test", "Access-Control-Request-Method": "POST"})
    assert r.headers.get("access-control-allow-origin") in ("*", "https://evil.test")
    assert "access-control-allow-credentials" not in r.headers


# ----------------------------------------------------------------------------- PDF / Excel injection
def test_pdf_generation_escapes_user_controlled_markup(db, sandbox_storage, monkeypatch, tmp_path):
    from app.services import pdf_generator

    evil = '<unclosed & <b>x</i> <img src="http://169.254.169.254/latest/meta-data/">.mp4'
    video = UploadedVideo(filename=evil, filepath="uploads/videos/a.mp4", processing_status="completed")
    db.add(video)
    db.commit()
    db.refresh(video)
    db.add(RoadDistress(
        video_id=video.id, distress_type="<font>pot&hole", severity="<b>high", confidence_score=0.9,
        latitude=1.0, longitude=2.0, status="detected", source_type="manual",
        detection_image_path="../../../../etc/passwd",
    ))
    db.commit()

    original = pdf_generator.SimpleDocTemplate
    out = tmp_path / "out.pdf"
    monkeypatch.setattr(pdf_generator, "SimpleDocTemplate", lambda path, **kw: original(str(out), **kw))

    rel = pdf_generator.generate_video_pdf_report(db, video.id)  # raises on unescaped markup
    assert rel.startswith("reports/generated/")
    assert out.read_bytes().startswith(b"%PDF")


def test_pdf_never_opens_images_outside_uploads(db, sandbox_storage, monkeypatch, tmp_path):
    from app.services import pdf_generator
    secret = sandbox_storage.root / "secret.png"
    secret.write_bytes(b"\x89PNG\r\n\x1a\n")
    opened = []
    monkeypatch.setattr(pdf_generator, "Image", lambda path, **kw: opened.append(path) or pdf_generator.Spacer(1, 1))
    original = pdf_generator.SimpleDocTemplate
    monkeypatch.setattr(pdf_generator, "SimpleDocTemplate", lambda path, **kw: original(str(tmp_path / "o.pdf"), **kw))

    video = UploadedVideo(filename="v.mp4", filepath="uploads/videos/v.mp4", processing_status="completed")
    db.add(video)
    db.commit()
    db.refresh(video)
    inside = sandbox_storage.uploads_dir / "detections" / "f.jpg"
    inside.parent.mkdir(parents=True)
    inside.write_bytes(b"\xff\xd8\xff")
    for path in ("../secret.png", str(secret), "uploads/../secret.png", "uploads/detections/f.jpg?x=1"):
        db.add(RoadDistress(video_id=video.id, distress_type="pothole", severity="high", confidence_score=0.9,
                            latitude=1.0, longitude=2.0, status="detected", source_type="manual", detection_image_path=path))
    db.commit()
    pdf_generator.generate_video_pdf_report(db, video.id)
    assert [p for p in opened if "secret" in p] == []
    assert len(opened) == 1 and opened[0].endswith("f.jpg")


def test_excel_neutralises_formula_injection():
    from app.services.excel_generator import _text_cell
    for payload in ("=HYPERLINK(\"http://evil\",\"x\")", "+1+1", "-2+3", "@SUM(A1)", "\t=1", "\r=1"):
        assert not _text_cell(payload).startswith(("=", "+", "-", "@", "\t", "\r"))
        assert _text_cell(payload).endswith(payload)
    assert _text_cell("normal.mp4") == "normal.mp4"
    assert _text_cell(None) is None


# ----------------------------------------------------------------------------- schema constraints
@pytest.mark.parametrize(
    "overrides",
    [
        {"severity": "apocalyptic"}, {"confidence_score": 1.5}, {"latitude": 91}, {"longitude": 181},
        {"distress_type": ""}, {"distress_type": "x" * 101}, {"model_source": "evil"}, {"frame_number": -1},
    ],
)
def test_distress_create_constraints(client, make_user, overrides):
    _, _, headers = make_user()
    payload = {"distress_type": "pothole", "severity": "high", "confidence_score": 0.9, "latitude": 19.0, "longitude": 72.0}
    assert client.post("/api/v1/distress/", headers=headers, json=payload).status_code == 201
    assert client.post("/api/v1/distress/", headers=headers, json={**payload, **overrides}).status_code == 422


def test_distress_update_constraints(client, make_user):
    _, _, headers = make_user()
    created = client.post("/api/v1/distress/", headers=headers,
                          json={"distress_type": "pothole", "severity": "high", "confidence_score": 0.9, "latitude": 19.0, "longitude": 72.0}).json()
    url = f"/api/v1/distress/{created['id']}"
    assert client.put(url, headers=headers, json={"status": "completed"}).status_code == 200
    assert client.put(url, headers=headers, json={"severity": "meh"}).status_code == 422
    assert client.put(url, headers=headers, json={"latitude": 1000}).status_code == 422
    assert client.put(url, headers=headers, json={"detection_image_path": "../../x"}).status_code in (200, 422)
    again = client.get(url, headers=headers).json()
    assert again["detection_image_path"] is None, "clients cannot set server-side file references"
