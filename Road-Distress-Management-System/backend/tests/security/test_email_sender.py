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
