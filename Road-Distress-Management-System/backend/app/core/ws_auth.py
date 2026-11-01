"""
First-message authentication for WebSocket endpoints.

Browsers cannot set an ``Authorization`` header on a WebSocket handshake, and
putting the token in the URL leaks it into logs and proxies. Instead the client
connects and its FIRST message must be a text frame:

    {"type": "auth", "token": "<session token>"}

The server answers by closing with code 1008 (policy violation) if the message
does not arrive within ``AUTH_TIMEOUT_SECONDS`` or the token is invalid/expired.
"""

import asyncio
import json
import logging
from typing import Optional

from fastapi import WebSocket
from starlette.concurrency import run_in_threadpool

from app.core.deps import user_for_token
from app.db.session import SessionLocal
from app.models.user import User

logger = logging.getLogger(__name__)

AUTH_TIMEOUT_SECONDS = 5.0
WS_POLICY_VIOLATION = 1008


def _lookup_user(token: str) -> Optional[User]:
    db = SessionLocal()
    try:
        user = user_for_token(db, token)
        if user is not None:
            db.expunge(user)
        return user
    finally:
        db.close()


async def authenticate_websocket(websocket: WebSocket) -> Optional[User]:
    """
    Call right after ``websocket.accept()``. Returns the authenticated user, or closes the
    socket (code 1008) and returns None.
    """
    try:
        message = await asyncio.wait_for(websocket.receive(), timeout=AUTH_TIMEOUT_SECONDS)
    except (asyncio.TimeoutError, Exception):
        await _close(websocket, "Authentication required")
        return None

    if message.get("type") != "websocket.receive" or not message.get("text"):
        await _close(websocket, "Authentication required")
        return None
    try:
        payload = json.loads(message["text"])
        token = payload.get("token") if isinstance(payload, dict) and payload.get("type") == "auth" else None
    except (ValueError, TypeError):
        token = None
    if not isinstance(token, str) or not token or len(token) > 256:
        await _close(websocket, "Authentication required")
        return None

    user = await run_in_threadpool(_lookup_user, token)
    if user is None:
        await _close(websocket, "Invalid or expired session")
        return None
    return user


async def _close(websocket: WebSocket, reason: str) -> None:
    try:
        await websocket.close(code=WS_POLICY_VIOLATION, reason=reason)
    except Exception:
        pass
