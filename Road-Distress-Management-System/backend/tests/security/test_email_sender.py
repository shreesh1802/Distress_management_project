"""
The stdlib SMTP sender, exercised against a tiny in-process fake SMTP server (no network, no real provider).
"""

import socketserver
import threading

import pytest

from app.core.config import settings
from app.services import email_sender, otp_service


class _Handler(socketserver.StreamRequestHandler):
    def _send(self, line: str) -> None:
        self.wfile.write((line + "\r\n").encode())

    def handle(self) -> None:
        self._send("220 fake.smtp ready")
        data_mode = False
        body = []
        while True:
            raw = self.rfile.readline()
            if not raw:
                return
            line = raw.decode("utf-8", "replace").rstrip("\r\n")
            if data_mode:
                if line == ".":
                    data_mode = False
                    self.server.messages.append("\n".join(body))
                    self._send("250 queued")
                else:
                    body.append(line)
                continue
            cmd = line.upper()
            if cmd.startswith("EHLO") or cmd.startswith("HELO"):
                self._send("250-fake.smtp")
                self._send("250 AUTH PLAIN LOGIN" if self.server.offer_auth else "250 OK")
            elif cmd.startswith("AUTH"):
                self.server.auth_attempts.append(line)
                self._send("235 authenticated")
            elif cmd.startswith("MAIL FROM") or cmd.startswith("RCPT TO"):
                self._send("250 OK")
            elif cmd == "DATA":
                data_mode = True
                body.clear()
                self._send("354 end with .")
            elif cmd == "QUIT":
                self._send("221 bye")
                return
            else:
                self._send("250 OK")


class FakeSmtp(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, offer_auth=False):
        super().__init__(("127.0.0.1", 0), _Handler)
        self.messages = []
        self.auth_attempts = []
        self.offer_auth = offer_auth


@pytest.fixture()
def smtp_server():
    server = FakeSmtp()
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield server
    server.shutdown()
    server.server_close()


def configure(monkeypatch, server, **extra):
    monkeypatch.setattr(settings, "SMTP_HOST", "127.0.0.1")
    monkeypatch.setattr(settings, "SMTP_PORT", server.server_address[1])
    monkeypatch.setattr(settings, "SMTP_FROM", "Road Inspection <noreply@example.test>")
    monkeypatch.setattr(settings, "SMTP_STARTTLS", "false")
    for key, value in extra.items():
        monkeypatch.setattr(settings, key, value)


def test_otp_email_is_delivered_with_the_code(smtp_server, monkeypatch):
    configure(monkeypatch, smtp_server)
    assert email_sender.send_otp_email("person@example.test", "493021", 10) is True
    assert len(smtp_server.messages) == 1
    message = smtp_server.messages[0]
    assert "493021" in message and "10 minutes" in message
    assert "To: person@example.test" in message and "Subject: Your Road Inspection login code" in message


def test_login_flow_delivers_the_code_by_email_in_production(client, make_user, smtp_server, monkeypatch):
    configure(monkeypatch, smtp_server, APP_ENV="production")
    _, email, _ = make_user()
    r = client.post("/api/v1/auth/request-otp", json={"email": email})
    assert r.json() == {"sent": True, "dev_otp": None}
    assert len(smtp_server.messages) == 1  # delivered through the background task
    code = next(tok for tok in smtp_server.messages[0].split() if tok.isdigit() and len(tok) == 6)
    assert client.post("/api/v1/auth/verify-otp", json={"email": email, "code": code}).status_code == 200


def test_smtp_login_is_used_when_credentials_are_configured(smtp_server, monkeypatch):
    smtp_server.offer_auth = True
    configure(monkeypatch, smtp_server, SMTP_USER="mailer", SMTP_PASSWORD="app-password")
    assert email_sender.send_email("person@example.test", "s", "b") is True
    assert smtp_server.auth_attempts, "AUTH was not attempted although SMTP_USER/SMTP_PASSWORD are set"


def test_malformed_recipients_are_refused_without_connecting(smtp_server, monkeypatch):
    configure(monkeypatch, smtp_server)
    for bad in ("no-at-sign", "a@b", "x@y.test\r\nBcc: attacker@evil.test", "<a@b.test>", ""):
        assert email_sender.send_email(bad, "s", "b") is False
    assert smtp_server.messages == []


def test_failures_are_swallowed_and_do_not_leak(monkeypatch, caplog):
    monkeypatch.setattr(settings, "SMTP_HOST", "127.0.0.1")
    monkeypatch.setattr(settings, "SMTP_PORT", 1)  # nothing listens here
    monkeypatch.setattr(settings, "SMTP_FROM", "noreply@example.test")
    monkeypatch.setattr(settings, "SMTP_STARTTLS", "false")
    assert email_sender.send_otp_email("person@example.test", "123456", 10) is False
    assert "123456" not in caplog.text


def test_unconfigured_smtp_returns_false(monkeypatch):
    monkeypatch.setattr(settings, "SMTP_HOST", None)
    assert email_sender.send_email("person@example.test", "s", "b") is False


def test_deliver_otp_email_never_logs_the_code(monkeypatch, caplog):
    monkeypatch.setattr(email_sender, "send_otp_email", lambda *a, **k: False)
    otp_service.deliver_otp_email("person@example.test", "654321")
    assert "654321" not in caplog.text


# ------------------------------------------------------------------ Brevo HTTPS API path
import http.server  # noqa: E402
import json  # noqa: E402


class FakeBrevo(http.server.ThreadingHTTPServer):
    def __init__(self, status=201, reply=b"{}"):
        super().__init__(("127.0.0.1", 0), _BrevoHandler)
        self.requests = []
        self.status = status
        self.reply = reply


class _BrevoHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("content-length", 0))
        self.server.requests.append(
            {"path": self.path, "headers": {k.lower(): v for k, v in self.headers.items()}, "body": json.loads(self.rfile.read(length) or b"{}")}
        )
        self.send_response(self.server.status)
        self.send_header("content-type", "application/json")
        self.end_headers()
        self.wfile.write(self.server.reply)

    def log_message(self, *args):  # keep test output quiet
        pass


@pytest.fixture()
def brevo(monkeypatch):
    server = FakeBrevo()
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    monkeypatch.setattr(email_sender, "BREVO_API_URL", f"http://127.0.0.1:{server.server_address[1]}/v3/smtp/email")
    monkeypatch.setattr(settings, "BREVO_API_KEY", "test-api-key-123")
    monkeypatch.setattr(settings, "SMTP_FROM", "Road Inspection <noreply@example.test>")
    yield server
    server.shutdown()
    server.server_close()


def test_brevo_api_delivers_the_code_over_http(brevo):
    assert email_sender.send_otp_email("user@example.test", "482913", 10) is True
    (req,) = brevo.requests
    assert req["path"] == "/v3/smtp/email"
    assert req["headers"]["api-key"] == "test-api-key-123"
    assert req["body"]["sender"] == {"email": "noreply@example.test", "name": "Road Inspection"}
    assert req["body"]["to"] == [{"email": "user@example.test"}]
    assert "482913" in req["body"]["textContent"]


def test_brevo_is_preferred_over_smtp_when_both_are_configured(brevo, smtp_server, monkeypatch):
    monkeypatch.setattr(settings, "SMTP_HOST", "127.0.0.1")
    monkeypatch.setattr(settings, "SMTP_PORT", smtp_server.server_address[1])
    assert email_sender.send_otp_email("user@example.test", "111222", 10) is True
    assert len(brevo.requests) == 1 and smtp_server.messages == []


def test_brevo_error_is_logged_without_the_key_or_code(brevo, caplog):
    brevo.status = 401
    brevo.reply = b'{"message": "Key not found"}'
    with caplog.at_level("ERROR"):
        assert email_sender.send_otp_email("user@example.test", "482913", 10) is False
    text = caplog.text
    assert "HTTP 401" in text and "Key not found" in text
    assert "test-api-key-123" not in text and "482913" not in text


def test_brevo_needs_a_sender_address(brevo, monkeypatch):
    monkeypatch.setattr(settings, "SMTP_FROM", None)
    assert settings.email_api_configured is False
    assert email_sender.send_email("user@example.test", "s", "b") is False
    assert brevo.requests == []


def test_login_flow_delivers_via_brevo_in_production(client, make_user, brevo, monkeypatch):
    monkeypatch.setattr(settings, "APP_ENV", "production")
    _uid, email, _h = make_user("employee")
    r = client.post("/api/v1/auth/request-otp", json={"email": email})
    assert r.status_code == 200 and r.json()["dev_otp"] is None
    assert any(email == q["body"]["to"][0]["email"] for q in brevo.requests)


def test_startup_accepts_brevo_without_any_smtp_host():
    from app.core.config import Settings
    from app.core.startup_checks import collect_config_errors
    cfg = Settings(
        _env_file=None, APP_ENV="production", BREVO_API_KEY="k", SMTP_FROM="x@example.test",
        DOWNLOAD_SIGNING_SECRET="aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3zA5",
    )
    assert collect_config_errors(cfg) == []
    assert any("E-mail delivery" in e for e in collect_config_errors(Settings(
        _env_file=None, APP_ENV="production", DOWNLOAD_SIGNING_SECRET="aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3zA5")))
