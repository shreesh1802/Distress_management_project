"""
Pure-ASGI middleware adding conservative security headers to every HTTP response.

Deliberately NOT set here: Content-Security-Policy and Strict-Transport-Security. The
Flutter web build served by nginx needs a CSP tailored to its CanvasKit/wasm assets, and HSTS
only makes sense once TLS terminates in front of the app -- both belong in nginx.conf
(see SECURITY.md for a starting point).
"""

from starlette.datastructures import MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send


class SecurityHeadersMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        path = scope.get("path", "")

        async def send_with_headers(message: Message) -> None:
            if message["type"] == "http.response.start":
                headers = MutableHeaders(scope=message)
                headers["X-Content-Type-Options"] = "nosniff"
                headers["X-Frame-Options"] = "DENY"
                headers["Referrer-Policy"] = "no-referrer"
                if path.startswith("/api/"):
                    # API responses carry personal / session data: never cache them.
                    headers["Cache-Control"] = "no-store"
            await send(message)

        await self.app(scope, receive, send_with_headers)
