"""
Live detection hardening: WebSocket first-message authentication, session ownership, frame limits,
no filesystem paths in the public status payload. The detector itself is stubbed -- no model is loaded.
"""

import json
import struct

import pytest
from starlette.websockets import WebSocketDisconnect

from app.api.v1.routes import live as live_routes
from app.services.live.live_camera_service import LiveCameraManager


@pytest.fixture()
def fake_manager(monkeypatch):
    """Every user's session is this one manager, whose heavy methods are replaced with recorders."""
    manager = LiveCameraManager()
    monkeypatch.setattr(LiveCameraManager, "for_user", classmethod(lambda cls, user_id: manager))
    calls = {"start_remote": 0, "stop": 0, "frames": 0}
    state = {"start_status": "started", "manager": manager}

    def start_remote(*a, **k):
        calls["start_remote"] += 1
        return {"status": state["start_status"]}

    monkeypatch.setattr(manager, "start_remote", start_remote)
    monkeypatch.setattr(manager, "push_frame", lambda frame: calls.__setitem__("frames", calls["frames"] + 1))
    monkeypatch.setattr(manager, "stop", lambda: (calls.__setitem__("stop", calls["stop"] + 1), {"status": "stopped"})[1])
    return calls, state


def jpeg_header(width, height):
    """Minimal byte string that image_dimensions() reads as a JPEG of the given size."""
    sof = b"\xff\xc0" + struct.pack(">HBHHB", 11, 8, height, width, 1) + b"\x01\x11\x00"
    return b"\xff\xd8" + sof + b"\x00" * 16


def auth_msg(token):
    return json.dumps({"type": "auth", "token": token})


# ----------------------------------------------------------------------------- WebSocket authentication
@pytest.mark.parametrize("path", ["/api/v1/live/ws", "/api/v1/live/phone-stream"])
@pytest.mark.parametrize("first_message", ["hello", "{}", '{"type":"auth"}', '{"type":"auth","token":""}',
                                           '{"type":"auth","token":123}', '{"type":"x","token":"abc"}', "[1,2]"])
def test_websockets_reject_a_bad_first_message(client, fake_manager, path, first_message):
    with client.websocket_connect(path) as ws:
        ws.send_text(first_message)
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_text()
    assert exc.value.code == 1008
    assert fake_manager[0]["start_remote"] == 0


@pytest.mark.parametrize("path", ["/api/v1/live/ws", "/api/v1/live/phone-stream"])
def test_websockets_reject_unknown_and_expired_tokens(client, fake_manager, path):
    with client.websocket_connect(path) as ws:
        ws.send_text(auth_msg("0" * 64))
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_text()
    assert exc.value.code == 1008
    assert fake_manager[0]["start_remote"] == 0


def test_binary_first_frame_is_rejected(client, fake_manager):
    with client.websocket_connect("/api/v1/live/phone-stream") as ws:
        ws.send_bytes(b"\xff\xd8\xff\xe0 frame before auth")
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_bytes()
    assert exc.value.code == 1008 and fake_manager[0]["frames"] == 0


def test_token_in_the_url_is_not_accepted(client, fake_manager, make_user):
    _, _, headers = make_user()
    token = headers["Authorization"].split()[1]
    with client.websocket_connect(f"/api/v1/live/ws?token={token}") as ws:
        ws.send_text("{}")
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_text()
    assert exc.value.code == 1008


def test_status_socket_works_after_authentication(client, make_user):
    _, _, headers = make_user()
    token = headers["Authorization"].split()[1]
    with client.websocket_connect("/api/v1/live/ws") as ws:
        ws.send_text(auth_msg(token))
        message = ws.receive_json()
    assert set(message) == {"status", "events"}
    assert "running" in message["status"]


# ----------------------------------------------------------------------------- phone-stream ownership + limits
def test_only_the_owning_connection_stops_the_session(client, fake_manager, make_user):
    calls, state = fake_manager
    _, _, headers = make_user()
    token = headers["Authorization"].split()[1]

    # connection that owns the session: stop() runs when it closes
    with client.websocket_connect("/api/v1/live/phone-stream") as ws:
        ws.send_text(auth_msg(token))
        ws.send_bytes(jpeg_header(64, 64))
    assert calls["start_remote"] == 1 and calls["stop"] == 1

    # connection that is refused because a session already runs must NOT stop it
    calls["stop"] = 0
    state["start_status"] = "already_running"
    with client.websocket_connect("/api/v1/live/phone-stream") as ws:
        ws.send_text(auth_msg(token))
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_bytes()
    assert exc.value.code == 1013
    assert calls["stop"] == 0, "a rejected second connection must leave the first caller's session running"


def test_oversize_frames_close_the_socket(client, fake_manager, make_user, monkeypatch):
    calls, _ = fake_manager
    _, _, headers = make_user()
    token = headers["Authorization"].split()[1]
    monkeypatch.setattr(live_routes, "MAX_FRAME_BYTES", 1000)
    with client.websocket_connect("/api/v1/live/phone-stream") as ws:
        ws.send_text(auth_msg(token))
        ws.send_bytes(jpeg_header(64, 64) + b"\x00" * 2000)
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_bytes()
    assert exc.value.code == 1009
    assert calls["frames"] == 0 and calls["stop"] == 1


def test_huge_declared_dimensions_close_the_socket_before_decoding(client, fake_manager, make_user, monkeypatch):
    calls, _ = fake_manager
    _, _, headers = make_user()
    token = headers["Authorization"].split()[1]

    def boom(*a, **k):
        raise AssertionError("an image with absurd dimensions must never reach the decoder")

    monkeypatch.setattr(live_routes.cv2, "imdecode", boom)
    with client.websocket_connect("/api/v1/live/phone-stream") as ws:
        ws.send_text(auth_msg(token))
        ws.send_bytes(jpeg_header(60000, 60000))
        with pytest.raises(WebSocketDisconnect) as exc:
            ws.receive_bytes()
    assert exc.value.code == 1008 and calls["frames"] == 0


def test_garbage_frames_are_skipped_not_decoded(client, fake_manager, make_user, monkeypatch):
    calls, _ = fake_manager
    _, _, headers = make_user()
    token = headers["Authorization"].split()[1]
    monkeypatch.setattr(live_routes.cv2, "imdecode", lambda *a, **k: (_ for _ in ()).throw(AssertionError("decoded")))
    with client.websocket_connect("/api/v1/live/phone-stream") as ws:
        ws.send_text(auth_msg(token))
        ws.send_bytes(b"not an image at all")
    assert calls["frames"] == 0


def test_every_received_frame_is_acknowledged_so_the_phone_can_pace_itself(client, fake_manager, make_user):
    calls, _ = fake_manager
    _, _, headers = make_user()
    token = headers["Authorization"].split()[1]
    with client.websocket_connect("/api/v1/live/phone-stream") as ws:
        ws.send_text(auth_msg(token))
        ws.send_bytes(b"not an image at all")          # skipped frames are acknowledged too, or the phone would stall
        assert ws.receive_bytes() == live_routes.FRAME_ACK
        ws.send_bytes(jpeg_header(64, 64))
        assert ws.receive_bytes() == live_routes.FRAME_ACK


def test_phone_location_messages_set_the_detection_position(client, fake_manager, make_user, monkeypatch):
    manager = fake_manager[1]["manager"]
    monkeypatch.setattr(manager, "_device_fix", None)
    _, _, headers = make_user()
    token = headers["Authorization"].split()[1]
    with client.websocket_connect("/api/v1/live/phone-stream") as ws:
        ws.send_text(auth_msg(token))
        for bad in ("not json", '{"type":"location","lat":999,"lon":1}', '{"type":"location","lat":true,"lon":1}',
                    '{"type":"other","lat":1,"lon":1}', '{"type":"location","lat":"28.6","lon":"77.2"}'):
            ws.send_text(bad)
        ws.send_text(json.dumps({"type": "location", "lat": 28.6139, "lon": 77.2090, "accuracy": 5}))
        ws.send_bytes(jpeg_header(64, 64))                # location messages get no ack; the frame does
        assert ws.receive_bytes() == live_routes.FRAME_ACK
    assert manager._device_fix[:3] == (28.6139, 77.2090, 5.0)
    assert manager._detection_position() == (28.6139, 77.209)
    assert manager.stats["gps_source"] == "device"


def test_stale_or_missing_phone_location_falls_back_to_the_default_position(monkeypatch):
    from app.services.live import live_camera_service as svc
    manager = LiveCameraManager.instance()
    monkeypatch.setattr(manager, "base_lat", 30.0)
    monkeypatch.setattr(manager, "base_lon", 76.0)
    monkeypatch.setattr(manager, "_device_fix", None)
    lat, lon = manager._detection_position()
    assert abs(lat - 30.0) <= 0.0005 and abs(lon - 76.0) <= 0.0005
    assert manager.stats["gps_source"] == "default"

    old = svc.time.monotonic() - (svc.cfg.DEVICE_FIX_MAX_AGE_SEC + 1)
    monkeypatch.setattr(manager, "_device_fix", (28.6, 77.2, 5.0, old))
    lat, lon = manager._detection_position()
    assert abs(lat - 30.0) <= 0.0005, "a fix older than the max age must not be used"


def test_image_dimensions_parser():
    assert live_routes.image_dimensions(jpeg_header(640, 480)) == (640, 480)
    png = b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" + struct.pack(">II", 320, 200) + b"\x00" * 10
    assert live_routes.image_dimensions(png) == (320, 200)
    assert live_routes.image_dimensions(b"") is None
    assert live_routes.image_dimensions(b"GIF89a") is None
    assert live_routes.image_dimensions(b"\xff\xd8\xff\xe0\x00") is None  # truncated


# ----------------------------------------------------------------------------- HTTP surface
def test_live_http_routes_require_auth(client):
    for method, path in (("post", "/api/v1/live/start"), ("post", "/api/v1/live/stop"),
                         ("get", "/api/v1/live/status"), ("get", "/api/v1/live/stream")):
        assert getattr(client, method)(path).status_code == 401, path


def test_live_status_has_no_filesystem_paths(client, make_user):
    class FakeDetector:
        source = "fallback"
        exp_source = "built-in:yolox-m"
        class_names = ["pothole"]
        ckpt_path = "C:/secret/models/road_best.pth"
        configured_exp_file = "C:/secret/live_test/exp.py"
        configured_ckpt_file = "C:/secret/live_test/ckpt.pth"

    info = LiveCameraManager._public_model_info(FakeDetector())
    assert info == {"source": "fallback", "exp_source": "built-in:yolox-m", "class_names": ["pothole"]}
    FakeDetector.exp_source = "C:/secret/live_test/exp.py"
    assert "secret" not in json.dumps(LiveCameraManager._public_model_info(FakeDetector()))

    _, _, headers = make_user()
    body = client.get("/api/v1/live/status", headers=headers).text
    assert "ckpt" not in body and ":\\" not in body


def test_start_failure_message_is_generic(client, make_user, monkeypatch):
    _, _, headers = make_user()
    manager = LiveCameraManager()
    monkeypatch.setattr(LiveCameraManager, "for_user", classmethod(lambda cls, user_id: manager))

    def explode(**kwargs):
        raise FileNotFoundError("model missing at C:\\very\\secret\\path\\road_best.pth")

    monkeypatch.setattr(manager, "start", explode)
    r = client.post("/api/v1/live/start", headers=headers, json={"camera_index": 1})
    assert r.status_code == 503
    assert "secret" not in r.text and "road_best" not in r.text


def test_live_start_request_is_validated(client, make_user):
    _, _, headers = make_user()
    for body in ({"camera_index": -1}, {"camera_index": 999}, {"latitude": 200}, {"longitude": -999}):
        assert client.post("/api/v1/live/start", headers=headers, json=body).status_code == 422


# ----------------------------------------------------------------------------- one session per user
@pytest.fixture()
def separate_sessions(monkeypatch):
    """Real per-user sessions (a fresh registry), with model loading and the loops stubbed out."""
    monkeypatch.setattr(LiveCameraManager, "_sessions", {})
    monkeypatch.setattr(LiveCameraManager, "_ensure_models_loaded", lambda self: None)
    monkeypatch.setattr(LiveCameraManager, "_inference_loop", lambda self: self._running.wait(5))
    monkeypatch.setattr(LiveCameraManager, "_capture_loop", lambda self, index: self._running.wait(5))
    yield
    for session in list(LiveCameraManager._sessions.values()):
        session._running.clear()


def test_each_user_has_their_own_session(separate_sessions):
    alice, bob = LiveCameraManager.for_user(1), LiveCameraManager.for_user(2)
    assert alice is not bob and LiveCameraManager.for_user(1) is alice
    assert alice.start_remote()["status"] == "started"
    assert bob.start_remote()["status"] == "started", "another user's running session must not block this one"
    alice.stop()
    assert not alice.is_running() and bob.is_running(), "stopping one user's session must leave the other running"


def test_stopping_over_http_only_stops_the_callers_session(client, make_user, separate_sessions):
    alice_id, _, alice = make_user()
    bob_id, _, bob = make_user()
    LiveCameraManager.for_user(alice_id).start_remote()
    LiveCameraManager.for_user(bob_id).start_remote()

    assert client.post("/api/v1/live/stop", headers=bob).status_code == 200
    assert client.get("/api/v1/live/status", headers=alice).json()["running"] is True
    assert client.get("/api/v1/live/status", headers=bob).json()["running"] is False


def test_the_servers_own_camera_is_used_by_one_session_at_a_time(client, make_user, separate_sessions):
    _, _, alice = make_user()
    _, _, bob = make_user()
    assert client.post("/api/v1/live/start", headers=alice, json={"camera_index": 1}).status_code == 200
    r = client.post("/api/v1/live/start", headers=bob, json={"camera_index": 1})
    assert r.status_code == 409 and "someone else" in r.json()["detail"]
