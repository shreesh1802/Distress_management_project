"""
Start-up download of the detection weights (used when the platform ships no / stub model files) and the
fail-fast behaviour of the video pipeline when the model is unavailable.
"""

import http.server
import os
import threading

import pytest

from app.core.config import settings
from app.services.ai import model_provisioning as mp

REAL = b"PK" + b"\x00" * (mp.MIN_REAL_SIZE + 10)  # looks like a torch zip checkpoint, large enough


class _Server(http.server.ThreadingHTTPServer):
    def __init__(self, files, redirect_to=None):
        super().__init__(("127.0.0.1", 0), _Handler)
        self.files = files
        self.redirect_to = redirect_to
        self.seen = []  # (path, authorization header)


class _Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.server.seen.append((self.path, self.headers.get("Authorization")))
        name = self.path.rsplit("/", 1)[-1]
        if self.server.redirect_to and name in self.server.files:
            self.send_response(302)
            self.send_header("Location", f"{self.server.redirect_to}/real/{name}")
            self.end_headers()
            return
        data = self.server.files.get(name)
        if data is None:
            self.send_response(404)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


def _serve(files, redirect_to=None):
    server = _Server(files, redirect_to)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


@pytest.fixture()
def models_dir(tmp_path):
    return str(tmp_path / "models")


@pytest.fixture()
def allow_plain_http(monkeypatch):
    """The test server speaks http://127.0.0.1; production URLs must be https (asserted separately)."""
    real_ensure = mp.ensure_models

    def ensure(models_dir=None):
        base = settings.MODEL_BASE_URL
        monkeypatch.setattr(settings, "MODEL_BASE_URL", base.replace("http://", "https://", 1))
        # swap the scheme check only: the downloader itself talks to the local http server
        original = mp._download
        monkeypatch.setattr(mp, "_download", lambda url, dest, token: original(url.replace("https://", "http://", 1), dest, token))
        return real_ensure(models_dir)

    return ensure


def test_missing_and_stub_files_are_detected(models_dir):
    os.makedirs(models_dir)
    assert mp.missing_weights(models_dir) == list(mp.WEIGHT_FILES)
    with open(os.path.join(models_dir, "road_best.pth"), "w") as f:  # a Git-LFS pointer stub
        f.write("version https://git-lfs.github.com/spec/v1\noid sha256:abc\nsize 202757334\n")
    assert "road_best.pth" in mp.missing_weights(models_dir)


def test_no_url_configured_returns_false_and_logs(models_dir, monkeypatch, caplog):
    monkeypatch.setattr(settings, "MODEL_BASE_URL", None)
    with caplog.at_level("ERROR"):
        assert mp.ensure_models(models_dir) is False
    assert "MODEL_BASE_URL is not set" in caplog.text


def test_plain_http_url_is_refused(models_dir, monkeypatch, caplog):
    monkeypatch.setattr(settings, "MODEL_BASE_URL", "http://example.test/models")
    with caplog.at_level("ERROR"):
        assert mp.ensure_models(models_dir) is False
    assert "https://" in caplog.text


def test_downloads_missing_files_and_replaces_stubs(models_dir, monkeypatch, allow_plain_http):
    os.makedirs(models_dir)
    with open(os.path.join(models_dir, "road_best.pth"), "w") as f:
        f.write("version https://git-lfs.github.com/spec/v1\n")
    server = _serve({"road_best.pth": REAL, "signage_best.pth": REAL})
    monkeypatch.setattr(settings, "MODEL_BASE_URL", f"http://127.0.0.1:{server.server_address[1]}/m")
    monkeypatch.setattr(settings, "MODEL_DOWNLOAD_TOKEN", "secret-token")

    assert allow_plain_http(models_dir) is True
    assert mp.missing_weights(models_dir) == []
    assert all(auth == "Bearer secret-token" for _p, auth in server.seen)
    assert not [f for f in os.listdir(models_dir) if f.endswith(".part")]
    server.shutdown()


def test_existing_real_files_are_left_alone(models_dir, monkeypatch):
    os.makedirs(models_dir)
    for name in mp.WEIGHT_FILES:
        with open(os.path.join(models_dir, name), "wb") as f:
            f.write(REAL)
    monkeypatch.setattr(settings, "MODEL_BASE_URL", None)
    assert mp.ensure_models(models_dir) is True


def test_bad_download_is_rejected_and_leaves_nothing_behind(models_dir, monkeypatch, allow_plain_http, caplog):
    server = _serve({"road_best.pth": b"<html>not a model</html>" * 10, "signage_best.pth": b"x"})
    monkeypatch.setattr(settings, "MODEL_BASE_URL", f"http://127.0.0.1:{server.server_address[1]}/m")
    with caplog.at_level("ERROR"):
        assert allow_plain_http(models_dir) is False
    assert os.listdir(models_dir) == []
    server.shutdown()


def test_http_error_message_never_contains_the_token(models_dir, monkeypatch, allow_plain_http, caplog):
    server = _serve({})  # everything 404s
    monkeypatch.setattr(settings, "MODEL_BASE_URL", f"http://127.0.0.1:{server.server_address[1]}/m")
    monkeypatch.setattr(settings, "MODEL_DOWNLOAD_TOKEN", "secret-token")
    with caplog.at_level("ERROR"):
        assert allow_plain_http(models_dir) is False
    assert "HTTP 404" in caplog.text and "secret-token" not in caplog.text
    server.shutdown()


def test_token_is_not_forwarded_to_a_different_host(models_dir, monkeypatch, allow_plain_http):
    cdn = _serve({"road_best.pth": REAL, "signage_best.pth": REAL})
    # "localhost" and "127.0.0.1" are different hosts as far as the redirect handler is concerned
    origin = _serve({"road_best.pth": b"", "signage_best.pth": b""}, redirect_to=f"http://localhost:{cdn.server_address[1]}")
    monkeypatch.setattr(settings, "MODEL_BASE_URL", f"http://127.0.0.1:{origin.server_address[1]}/m")
    monkeypatch.setattr(settings, "MODEL_DOWNLOAD_TOKEN", "secret-token")

    assert allow_plain_http(models_dir) is True
    assert origin.seen and all(auth == "Bearer secret-token" for _p, auth in origin.seen)  # sent to the configured host
    assert cdn.seen and all(auth is None for _p, auth in cdn.seen)                        # dropped on the redirect
    origin.shutdown()
    cdn.shutdown()


def test_pipeline_stops_at_the_first_frame_when_the_model_is_unavailable(client, monkeypatch, caplog, tmp_path):
    from app.db.session import SessionLocal
    from app.models.video import UploadedVideo
    from app.services.ai.model_loader import ModelUnavailableError
    from app.services.pipeline import pipeline_manager as pm

    calls = []

    def boom(*args, **kwargs):
        calls.append(1)
        raise ModelUnavailableError("The detection model is not available on this server.")

    monkeypatch.setattr(pm, "run_inference", boom)
    monkeypatch.setattr(
        pm, "extract_frames",
        lambda **kw: [{"frame_path": str(tmp_path / f"{i}.jpg"), "frame_number": i, "timestamp": float(i)} for i in range(50)],
    )

    db = SessionLocal()
    try:
        video = UploadedVideo(filename="v.mp4", filepath=str(tmp_path / "v.mp4"), processing_status="pending")
        db.add(video)
        db.commit()
        video_id = video.id
    finally:
        db.close()

    with caplog.at_level("ERROR"):
        pm.process_video(video_id)

    assert len(calls) == 1  # not 50
    assert caplog.text.count("Error processing frame") == 0

    db = SessionLocal()
    try:
        row = db.get(UploadedVideo, video_id)
        assert row.processing_status == "failed"
        assert "ModelUnavailableError" in (row.processing_stage or "")
    finally:
        db.close()
