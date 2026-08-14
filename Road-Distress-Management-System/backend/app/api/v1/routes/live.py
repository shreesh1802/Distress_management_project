"""
Live camera detection routes -- USB webcam on the server, or a remote client
(e.g. the phone app's own camera) streaming frames in over WebSocket.

Endpoints:
  POST /live/start          - start LOCAL USB camera + dual YOLOX inference
  WS   /live/phone-stream   - start a REMOTE session fed by pushed JPEG frames
                               (e.g. from the phone's own camera) instead of a
                               local camera device
  POST /live/stop           - stop the loop and release the camera
  GET  /live/status         - counters/state for polling clients
  GET  /live/stream         - MJPEG stream of annotated frames (use in an <img> tag)
  WS   /live/ws             - pushes status + detection events (~2Hz)
"""

import asyncio
import logging
import time
from typing import Any, Dict, Optional

import cv2
import numpy as np
from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from app.services.live.live_camera_service import LiveCameraManager

logger = logging.getLogger(__name__)
router = APIRouter()

MJPEG_BOUNDARY = "frame"


class LiveStartRequest(BaseModel):
    camera_index: int = Field(1, description="cv2 camera index (1 = external USB webcam)")
    latitude: Optional[float] = Field(None, description="Base GPS latitude for this session")
    longitude: Optional[float] = Field(None, description="Base GPS longitude for this session")


@router.post("/start")
def start_live(req: LiveStartRequest) -> Dict[str, Any]:
    """Start the live camera detection loop."""
    try:
        return LiveCameraManager.instance().start(
            camera_index=req.camera_index,
            latitude=req.latitude,
            longitude=req.longitude,
        )
    except (FileNotFoundError, RuntimeError) as e:
        # Model files missing or YOLOX not installed
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e))


@router.post("/stop")
def stop_live() -> Dict[str, Any]:
    """Stop the live camera detection loop and release the camera."""
    return LiveCameraManager.instance().stop()


@router.websocket("/phone-stream")
async def phone_stream(websocket: WebSocket) -> None:
    """
    Real-time detection fed by a remote client's own camera (the phone app)
    instead of a USB camera attached to this server.

    Protocol: after the WS handshake, send one binary message per frame --
    each message is a single JPEG-encoded image (whatever size/quality the
    client captures at; typical use is ~5-10fps to match the detection
    cadence, no need to match full camera framerate). The connection itself
    starts and stops the session -- closing it stops detection and releases
    the models' session state, same as POST /live/stop would.

    Detection results are read the normal way, via GET /live/status,
    GET /live/stream (MJPEG, still valid -- annotated from the last pushed
    frame), or WS /live/ws (event feed) -- this socket only accepts frames,
    it doesn't push results back, so a client typically has this connection
    open alongside a /live/ws connection for results.
    """
    await websocket.accept()
    manager = LiveCameraManager.instance()
    keepalive_task: Optional[asyncio.Task] = None
    start_time = time.monotonic()
    frames_received = 0
    keepalives_sent = 0
    client = f"{websocket.client.host}:{websocket.client.port}" if websocket.client else "unknown"
    try:
        result = manager.start_remote()
        if result.get("status") == "already_running":
            # Another session (local camera or a different phone) is already
            # active -- refuse rather than silently interleaving two sources
            # into one inference loop.
            await websocket.close(code=1013, reason="A live session is already running")
            return

        async def _keepalive():
            nonlocal keepalives_sent
            # This socket is intentionally one-way (client sends frames, this
            # handler never replies), so the reply direction sits idle for
            # the entire session even though frames are flowing steadily the
            # other way. Over a public tunnel + mobile carrier NAT, an idle
            # direction on an otherwise-active connection can still get
            # silently dropped -- a tiny periodic message on the otherwise-
            # silent direction is the standard fix.
            while True:
                await asyncio.sleep(8)
                await websocket.send_bytes(b"\x00")
                keepalives_sent += 1

        keepalive_task = asyncio.create_task(_keepalive())

        while True:
            data = await websocket.receive_bytes()
            frames_received += 1
            frame = cv2.imdecode(np.frombuffer(data, dtype=np.uint8), cv2.IMREAD_COLOR)
            if frame is not None:
                manager.push_frame(frame)
    except WebSocketDisconnect as e:
        elapsed = time.monotonic() - start_time
        logger.warning(
            f"Phone stream [{client}] disconnected after {elapsed:.1f}s -- "
            f"code={e.code} reason={e.reason!r} frames_received={frames_received} "
            f"keepalives_sent={keepalives_sent}"
        )
    except Exception as e:
        elapsed = time.monotonic() - start_time
        logger.warning(
            f"Phone stream [{client}] closed with exception after {elapsed:.1f}s -- "
            f"{type(e).__name__}: {e} -- frames_received={frames_received} "
            f"keepalives_sent={keepalives_sent}"
        )
    finally:
        if keepalive_task is not None:
            keepalive_task.cancel()
        manager.stop()


@router.get("/status")
def live_status() -> Dict[str, Any]:
    """Current live session state and counters."""
    return LiveCameraManager.instance().status()


@router.get("/stream")
async def live_stream() -> StreamingResponse:
    """
    MJPEG stream of annotated frames. Point an <img> tag at this URL:
        <img src="http://127.0.0.1:8000/api/v1/live/stream" />
    """
    manager = LiveCameraManager.instance()
    if not manager.is_running():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT,
                            detail="Live camera is not running. POST /live/start first.")

    async def gen():
        while manager.is_running():
            jpeg = manager.latest_jpeg()
            if jpeg is not None:
                yield (
                    b"--" + MJPEG_BOUNDARY.encode() + b"\r\n"
                    b"Content-Type: image/jpeg\r\n"
                    b"Content-Length: " + str(len(jpeg)).encode() + b"\r\n\r\n"
                    + jpeg + b"\r\n"
                )
            await asyncio.sleep(1 / 15)  # ~15 fps to the browser

    return StreamingResponse(
        gen(), media_type=f"multipart/x-mixed-replace; boundary={MJPEG_BOUNDARY}")


@router.websocket("/ws")
async def live_ws(websocket: WebSocket) -> None:
    """
    Pushes {"status": {...}, "events": [...]} every 0.5s. Events are the
    detections since the last message (each with class, confidence,
    severity, model_source, frame, time).
    """
    await websocket.accept()
    manager = LiveCameraManager.instance()
    last_seq = 0
    try:
        while True:
            events = manager.events_since(last_seq)
            if events:
                last_seq = events[-1]["seq"]
            await websocket.send_json({"status": manager.status(), "events": events})
            await asyncio.sleep(0.5)
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.warning(f"Live websocket closed: {e}")
