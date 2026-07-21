"""
Live USB camera detection routes.

Endpoints:
  POST /live/start   - start camera + dual YOLOX inference
  POST /live/stop    - stop the loop and release the camera
  GET  /live/status  - counters/state for polling clients
  GET  /live/stream  - MJPEG stream of annotated frames (use in an <img> tag)
  WS   /live/ws      - pushes status + detection events (~2Hz)
"""

import asyncio
import logging
from typing import Any, Dict, Optional

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
