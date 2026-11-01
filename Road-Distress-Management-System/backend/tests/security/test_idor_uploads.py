"""
Object-level authorization (IDOR) for projects / audits / assets / audio, plus upload validation.

Actors: an owner (non-admin), a member, an outsider (non-member) and an admin.
"""

import io
import os

import pytest

from app.models.asset import ProjectAsset
from app.models.audit import AuditAudioClip
from tests.security.conftest import unique_email

PDF = b"%PDF-1.4\n1 0 obj<<>>endobj\n%%EOF"


@pytest.fixture()
def world(client, make_user, admin):
    """owner creates a project that has `member` attached; `outsider` and `admin` exist too."""
    owner_id, owner_email, owner_h = make_user("employee")
    member_id, member_email, member_h = make_user("employee")
    outsider_id, outsider_email, outsider_h = make_user("employee")
    _, _, admin_h = admin

    r = client.post("/api/v1/projects/", headers=owner_h, json={"name": "NH-48 Survey", "member_emails": [member_email]})
    assert r.status_code == 201, r.text
    project = r.json()

    class World:
        pass

    w = World()
    w.project_id = project["id"]
    w.owner, w.member, w.outsider, w.admin = owner_h, member_h, outsider_h, admin_h
    w.owner_id, w.member_id, w.outsider_id = owner_id, member_id, outsider_id
    w.member_email = member_email
    return w


def make_audit(client, headers, project_id, title="Audit 1"):
    r = client.post(f"/api/v1/audits/?project_id={project_id}", headers=headers, json={"title": title})
    assert r.status_code == 201, r.text
    return r.json()["id"]


# ----------------------------------------------------------------------------- projects
def test_owner_sees_their_own_project_even_though_not_listed_as_member(client, world):
    listed = [p["id"] for p in client.get("/api/v1/projects/", headers=world.owner).json()]
    assert world.project_id in listed


def test_project_visibility_matrix(client, world):
    for who, expected in (("owner", True), ("member", True), ("admin", True), ("outsider", False)):
        headers = getattr(world, who)
        listed = [p["id"] for p in client.get("/api/v1/projects/", headers=headers).json()]
        assert (world.project_id in listed) is expected, who
        status = client.get(f"/api/v1/projects/{world.project_id}", headers=headers).status_code
        assert status == (200 if expected else 403), who


def test_unknown_project_is_404_not_403(client, world):
    assert client.get("/api/v1/projects/999999", headers=world.outsider).status_code == 404


def test_member_emails_are_normalised_and_deduplicated(client, make_user):
    _, owner_email, owner_h = make_user("employee")
    _, member_email, _ = make_user("employee")
    r = client.post("/api/v1/projects/", headers=owner_h,
                    json={"name": "P", "member_emails": [f" {member_email.upper()} ", member_email, "nobody@example.test"]})
    assert r.status_code == 201
    assert r.json()["member_emails"] == [member_email]


def test_project_input_limits(client, make_user):
    _, _, h = make_user("employee")
    too_many = [f"u{i}@example.test" for i in range(101)]
    assert client.post("/api/v1/projects/", headers=h, json={"name": "P", "member_emails": too_many}).status_code == 422
    assert client.post("/api/v1/projects/", headers=h, json={"name": "P", "member_emails": ["a" * 300 + "@x.test"]}).status_code == 422
    assert client.post("/api/v1/projects/", headers=h, json={"name": "x" * 300}).status_code == 422


# ----------------------------------------------------------------------------- audits
def test_audit_access_matrix(client, world):
    audit_id = make_audit(client, world.member, world.project_id)
    routes = [
        ("get", f"/api/v1/audits/{audit_id}"),
        ("get", f"/api/v1/audits/{audit_id}/checklist-items"),
        ("get", f"/api/v1/audits/{audit_id}/audio"),
        ("get", f"/api/v1/audits/{audit_id}/report/chainage"),
        ("get", f"/api/v1/audits/{audit_id}/report/audio"),
        ("get", f"/api/v1/audits/?project_id={world.project_id}"),
    ]
    for method, url in routes:
        for who, expected in (("owner", 200), ("member", 200), ("admin", 200), ("outsider", 403)):
            r = getattr(client, method)(url, headers=getattr(world, who))
            assert r.status_code == expected, (url, who, r.status_code)

    body = {"chainage_km": 1.5, "category": "signage", "severity": "high", "description": "Missing sign"}
    assert client.post(f"/api/v1/audits/{audit_id}/checklist-items", headers=world.outsider, json=body).status_code == 403
    assert client.post(f"/api/v1/audits/?project_id={world.project_id}", headers=world.outsider, json={"title": "x"}).status_code == 403
    assert client.post(f"/api/v1/audits/{audit_id}/checklist-items", headers=world.member, json=body).status_code == 201


def test_audio_cannot_be_deleted_through_a_different_audit(client, world, db, sandbox_storage):
    audit_a = make_audit(client, world.member, world.project_id, "A")
    other_project = client.post("/api/v1/projects/", headers=world.outsider, json={"name": "Other"}).json()["id"]
    audit_b = make_audit(client, world.outsider, other_project, "B")

    clip = AuditAudioClip(audit_id=audit_a, filename="c.webm", filepath="uploads/audio/c.webm", transcript_status="pending")
    db.add(clip)
    db.commit()
    db.refresh(clip)

    # outsider owns audit B and tries to delete audit A's clip through B
    assert client.delete(f"/api/v1/audits/{audit_b}/audio/{clip.id}", headers=world.outsider).status_code == 404
    # and directly through A
    assert client.delete(f"/api/v1/audits/{audit_a}/audio/{clip.id}", headers=world.outsider).status_code == 403
    assert client.delete(f"/api/v1/audits/{audit_a}/audio/{clip.id}", headers=world.member).status_code == 204


def test_audit_field_validation(client, world):
    audit_id = make_audit(client, world.member, world.project_id)
    url = f"/api/v1/audits/{audit_id}/checklist-items"
    good = {"chainage_km": 1.5, "category": "signage", "severity": "high", "description": "ok"}
    assert client.post(url, headers=world.member, json={**good, "severity": "catastrophic"}).status_code == 422
    assert client.post(url, headers=world.member, json={**good, "category": "<script>"}).status_code == 422
    assert client.post(url, headers=world.member, json={**good, "chainage_km": -1}).status_code == 422
    assert client.post(url, headers=world.member, json={**good, "description": ""}).status_code == 422
    assert client.post(url, headers=world.member, json={**good, "description": "x" * 2001}).status_code == 422
    # NaN / Infinity (accepted by Python's JSON parser) must be refused
    for bad in ("NaN", "Infinity", "-Infinity"):
        raw = '{"chainage_km": %s, "category": "signage", "severity": "low", "description": "d"}' % bad
        r = client.post(url, headers={**world.member, "Content-Type": "application/json"}, content=raw)
        assert r.status_code == 422, bad


def test_chainage_interval_is_bounded(client, world):
    audit_id = make_audit(client, world.member, world.project_id)
    base = f"/api/v1/audits/{audit_id}/report/chainage"
    assert client.get(base, headers=world.member).status_code == 200
    assert client.get(f"{base}?interval_km=0.25", headers=world.member).status_code == 200
    for bad in ("0", "-1", "100.5", "1e9", "nan", "inf"):
        assert client.get(f"{base}?interval_km={bad}", headers=world.member).status_code == 422, bad


# ----------------------------------------------------------------------------- assets
def upload_asset(client, headers, project_id, name="plan.pdf", content=PDF, category="report", ctype="application/pdf"):
    return client.post(
        f"/api/v1/assets/?project_id={project_id}", headers=headers,
        files={"file": (name, io.BytesIO(content), ctype)}, data={"category": category, "description": "d"},
    )


def test_asset_access_matrix(client, world, sandbox_storage):
    r = upload_asset(client, world.member, world.project_id)
    assert r.status_code == 201, r.text
    asset_id = r.json()["id"]

    assert upload_asset(client, world.outsider, world.project_id).status_code == 403
    for who, expected in (("owner", 200), ("member", 200), ("admin", 200), ("outsider", 403)):
        r = client.get(f"/api/v1/assets/?project_id={world.project_id}", headers=getattr(world, who))
        assert r.status_code == expected, who

    assert client.delete(f"/api/v1/assets/{asset_id}", headers=world.outsider).status_code == 403
    assert client.delete(f"/api/v1/assets/{asset_id}", headers=world.member).status_code == 204
    assert client.delete(f"/api/v1/assets/{asset_id}", headers=world.member).status_code == 404


def test_asset_in_another_project_cannot_be_deleted_by_a_member_of_a_different_one(client, world, sandbox_storage):
    other_project = client.post("/api/v1/projects/", headers=world.outsider, json={"name": "Other"}).json()["id"]
    foreign = upload_asset(client, world.outsider, other_project).json()["id"]
    assert client.delete(f"/api/v1/assets/{foreign}", headers=world.member).status_code == 403
    assert client.delete(f"/api/v1/assets/{foreign}", headers=world.admin).status_code == 204


def test_asset_content_type_is_derived_from_the_extension_not_the_client(client, world, db, sandbox_storage):
    r = upload_asset(client, world.member, world.project_id, ctype="text/html")
    assert r.status_code == 201
    assert r.json()["content_type"] == "application/pdf"
    assert db.get(ProjectAsset, r.json()["id"]).content_type == "application/pdf"


@pytest.mark.parametrize("name", ["run.exe", "page.html", "x.svg", "a.php", "noext", "evil.pdf.exe", "x.js"])
def test_disallowed_extensions_are_rejected(client, world, sandbox_storage, name):
    assert upload_asset(client, world.member, world.project_id, name=name).status_code == 400
    assert os.listdir(sandbox_storage.uploads_dir / "assets") == []


@pytest.mark.parametrize(
    "name, content",
    [
        ("fake.pdf", b"<html><script>alert(1)</script></html>"),
        ("fake.png", b"GIF89a....."),
        ("fake.jpg", b"%PDF-1.4"),
        ("fake.docx", b"MZ\x90\x00 not a zip"),
        ("fake.xlsx", b"hello"),
    ],
)
def test_content_that_contradicts_the_extension_is_rejected(client, world, sandbox_storage, name, content):
    r = upload_asset(client, world.member, world.project_id, name=name, content=content)
    assert r.status_code == 400 and "does not match" in r.text
    assert os.listdir(sandbox_storage.uploads_dir / "assets") == []


@pytest.mark.parametrize(
    "name, content",
    [
        ("ok.pdf", PDF),
        ("ok.png", b"\x89PNG\r\n\x1a\n" + b"0" * 20),
        ("ok.jpg", b"\xff\xd8\xff\xe0" + b"0" * 20),
        ("ok.jpeg", b"\xff\xd8\xff\xdb" + b"0" * 20),
        ("ok.docx", b"PK\x03\x04" + b"0" * 20),
        ("ok.xlsx", b"PK\x03\x04" + b"0" * 20),
        ("ok.csv", b"a,b\n1,2\n"),
        ("ok.txt", b"plain text"),
        ("ok.doc", b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"),
        ("ok.xls", b"<html>some exported sheets are really html</html>"),
    ],
)
def test_legitimate_files_are_accepted(client, world, sandbox_storage, name, content):
    assert upload_asset(client, world.member, world.project_id, name=name, content=content).status_code == 201


def test_oversize_asset_is_rejected_and_cleaned_up(client, world, sandbox_storage, monkeypatch):
    from app.services import asset as asset_service
    monkeypatch.setattr(asset_service, "MAX_FILE_SIZE_BYTES", 1024)
    r = upload_asset(client, world.member, world.project_id, content=PDF + b"0" * 4096)
    assert r.status_code == 413
    assert os.listdir(sandbox_storage.uploads_dir / "assets") == []


def test_asset_category_and_description_are_validated(client, world, sandbox_storage):
    assert upload_asset(client, world.member, world.project_id, category="<b>x</b>").status_code == 422
    r = client.post(
        f"/api/v1/assets/?project_id={world.project_id}", headers=world.member,
        files={"file": ("a.pdf", io.BytesIO(PDF), "application/pdf")}, data={"category": "report", "description": "d" * 2001},
    )
    assert r.status_code == 422


def test_stored_file_name_is_sanitised_and_unique(client, world, db, sandbox_storage):
    r = upload_asset(client, world.member, world.project_id, name="../../..\\evil name?.pdf")
    assert r.status_code == 201
    row = db.get(ProjectAsset, r.json()["id"])
    assert ".." not in row.filepath and "\\" not in row.filepath
    assert row.filepath.startswith("uploads/assets/")
    assert os.listdir(sandbox_storage.uploads_dir / "assets") != []


# ----------------------------------------------------------------------------- audio + video uploads
def test_audio_upload_validation(client, world, sandbox_storage):
    audit_id = make_audit(client, world.member, world.project_id)
    url = f"/api/v1/audits/{audit_id}/audio"

    def up(headers, name, content, **data):
        return client.post(url, headers=headers, files={"file": (name, io.BytesIO(content), "application/octet-stream")}, data=data)

    assert up(world.outsider, "a.mp3", b"ID3" + b"0" * 10).status_code == 403
    assert up(world.member, "a.exe", b"MZ").status_code == 400
    assert up(world.member, "a.wav", b"not a wav").status_code == 400
    assert up(world.member, "a.wav", b"RIFF\x24\x00\x00\x00WAVEfmt ").status_code == 201
    for name in ("a.webm", "a.ogg", "a.m4a", "a.mp3", "a.aac"):  # containers we deliberately do not sniff
        assert up(world.member, name, b"\x1aE\xdf\xa3 whatever").status_code == 201, name
    assert up(world.member, "b.mp3", b"ID3", chainage_km="-4").status_code == 422
    assert up(world.member, "b.mp3", b"ID3", chainage_km="nan").status_code == 422


def test_video_upload_rejects_bad_extension_and_oversize(client, make_user, sandbox_storage, monkeypatch):
    from app.services import video as video_service
    _, _, headers = make_user()
    bad = client.post("/api/v1/videos/upload", headers=headers, files={"file": ("x.exe", io.BytesIO(b"MZ"), "video/mp4")})
    assert bad.status_code == 400

    monkeypatch.setattr(video_service, "MAX_FILE_SIZE_BYTES", 512)
    big = client.post("/api/v1/videos/upload", headers=headers, files={"file": ("x.mp4", io.BytesIO(b"0" * 4096), "video/mp4")})
    assert big.status_code == 413
    assert os.listdir(sandbox_storage.uploads_dir / "videos") == []

    anon = client.post("/api/v1/videos/upload", files={"file": ("x.mp4", io.BytesIO(b"0" * 10), "video/mp4")})
    assert anon.status_code == 401
