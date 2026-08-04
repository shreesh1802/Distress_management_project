# Road Distress Management System - Backend Module

This repository module contains the production-ready FastAPI foundation for the Road Distress Management System.

The active frontend client is the Flutter Web app in [`mobile/`](../../mobile),
which talks to this backend directly at `http://127.0.0.1:8000` (see
[`mobile/README.md`](../../mobile/README.md)). The React app in `frontend/`
remains in the repo as the design/behavior reference the Flutter screens are
ported against.

## Architecture Directory Guide

```text
backend/
├── app/
│   ├── api/
│   │   └── v1/
│   │       ├── routes/          # API endpoint routers
│   │       │   ├── auth.py
│   │       │   ├── distress.py
│   │       │   ├── gis.py
│   │       │   ├── reports.py
│   │       │   ├── maintenance.py
│   │       │   └── upload.py
│   │       └── __init__.py
│   ├── core/                    # App settings and security configurations
│   │   ├── config.py
│   │   └── security.py
│   ├── db/                      # Database engine and session handlers
│   │   ├── database.py
│   │   └── session.py
│   ├── models/                  # Database models (SQLAlchemy)
│   ├── schemas/                 # Request & response validation schemas (Pydantic)
│   ├── services/                # Business logic services
│   ├── utils/                   # Shared helpers and utilities
│   └── main.py                  # Primary application entrypoint
├── requirements.txt             # Project dependencies
├── .env.example                 # Environment settings template
└── .gitignore                   # Ignored files list
```

## Setup & Local Installation

Follow these steps to run the backend application locally:

### 1. Create a Python Virtual Environment
Navigate to the `backend/` directory and run:
```bash
# Windows
python -m venv .venv
.venv\Scripts\activate

# macOS / Linux
python3 -m venv .venv
source .venv/bin/activate
```

### 2. Install Project Dependencies
With the virtual environment active, run:
```bash
pip install -r requirements.txt
```

### 3. Setup Configuration Variables
Copy the template `.env.example` file to `.env`:
```bash
# Windows (PowerShell)
Copy-Item .env.example .env

# macOS / Linux / Windows (Command Prompt)
cp .env.example .env
```

### 4. Execute the Application Server
Run the FastAPI application server using Uvicorn:
```bash
uvicorn app.main:app --reload
```

## API Documentation & Verification

Once the server starts up, verify the running instance at:

- **Health Check Endpoint**: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)
- **Interactive Swagger Documentation**: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **Alternative Redoc Documentation**: [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)

## Live Camera Detection

`app/api/v1/routes/live.py` runs real-time YOLOX inference (pavement +
signage models) against a USB camera attached to whichever machine is
running this backend — there is no browser-webcam-upload path, and this
service is not deployed anywhere; it's meant to run locally, next to the
camera.

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/api/v1/live/start` | Start the camera + dual-model inference loop (`camera_index`, optional `latitude`/`longitude`) |
| `POST` | `/api/v1/live/stop` | Stop the loop and release the camera |
| `GET` | `/api/v1/live/status` | Poll counters/state (fps, detection counts, running/error) |
| `GET` | `/api/v1/live/stream` | MJPEG stream of annotated frames — point an `<img>` tag or the Flutter `MjpegView` widget at it |
| `WS` | `/api/v1/live/ws` | Pushes `{"status": ..., "events": [...]}` roughly every 0.5s |

### Model files

`app/services/live/live_config.py` looks for YOLOX exp/checkpoint files
under `../live_test/` (sibling of `backend/`) by default, falling back to
`backend/models/road_best.pth` and `backend/models/signage_best.pth` if the
former aren't present. Every path and inference setting (camera index,
confidence/NMS thresholds, capture resolution, persistence cooldown) is
overridable via environment variables — see the top of `live_config.py` for
the full list (`LIVE_PAVEMENT_EXP`, `LIVE_CAMERA_INDEX`, `LIVE_CONF_THRESH`,
etc.). If neither the primary nor fallback checkpoints are found, `/live/start`
returns `503` with a descriptive `detail` message rather than crashing.

### Trying it with the Flutter client

1. Start this backend locally (steps above) with a USB camera attached.
2. Run the Flutter app from `mobile/` and open **Live Detection**.
3. Set the camera index (matches `cv2.VideoCapture`'s index — `1` is
   usually the first external USB webcam) and hit **Start Live Detection**.

If the backend isn't running, the Flutter screen still renders normally and
shows a clean "Failed to start live camera" error instead of crashing —
that's the expected/desired behavior when testing the UI standalone.
