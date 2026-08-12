# Road Distress Management System & Mobile Web Platform


##  Repository Code Architecture 

The repository is structured into two primary components:

```
Distress_management_project/
├── mobile/                                 # Flutter Cross-Platform App (Web, Android, iOS)
│   ├── lib/
│   │   ├── main.dart                      # Application Entrypoint & Theme Configuration
│   │   ├── router/app_router.dart          # GoRouter Navigation Setup
│   │   ├── data/                           # API Connectors & Data Models
│   │   │   ├── live_detection_api.dart     # Dynamic API Base URL calculation & WebSocket client
│   │   │   ├── road_distress_api.dart      # Distress Record Data Models & API endpoints
│   │   │   ├── video_api.dart              # Video upload & streaming connectors
│   │   │   └── reports_api.dart            # PDF & Excel report generation service
│   │   ├── screens/                        # UI Screen Modules
│   │   │   ├── dashboard/                  # Main Dashboard, Shell & Mobile Drawer/Navigation
│   │   │   ├── video_review/               # Dual Video Player & Detections Inspector
│   │   │   │   ├── video_review_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── web_video_card.dart # HTML5 Video Element & Independent Fullscreen
│   │   │   │       ├── dual_player_panel.dart
│   │   │   │       └── detections_sidebar.dart # Mobile Detections Cards & Play Clip triggers
│   │   │   └── reports/                    # Reports Registry & PDF/Excel Download Triggers
│   │   └── utils/
│   │       └── download_helper.dart        # JS Blob & cross-platform report downloader
│   └── build/
│       ├── web/                           # Compiled Production Web Assets (served on port 8080)
│       └── app/outputs/flutter-apk/       # Android APK release builds
│
└── Road-Distress-Management-System/
    └── backend/                            # FastAPI AI Backend & Database
        ├── app/
        │   ├── main.py                     # FastAPI Application Entry, CORS, APK Download & Auto-Seeding
        │   ├── api/v1/routes/              # API Route Handlers (videos, detection, reports)
        │   ├── models/                     # SQLAlchemy Models (distress.py, video.py, report.py)
        │   └── services/                   # PDF & Excel Generators, AI Pipeline Utils
        └── uploads/                        # Raw Videos, Processed Videos, AI Crops & APK builds
            ├── videos/                     # Raw surveillance MP4 files (+faststart H.264)
            ├── processed/                  # AI annotated MP4 files (H.264)
            ├── crops/                      # Zoomed-in AI distress crop image snippets
            └── RoadDistress.apk            # Android APK installer (downloadable via /download-apk)
```

---

##  First-Time Setup (once per machine)

Do this once per machine, in order, from PowerShell.


```powershell
cd <path-to-repo>
git lfs pull
```

** Create the backend virtual environment and install dependencies:**

```powershell
cd <path-to-repo>\Road-Distress-Management-System\backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

** Install YOLOX** 

```powershell
.\.venv\Scripts\python.exe -m pip install cmake ninja
.\.venv\Scripts\python.exe -m pip install yolox==0.3.0 --no-deps --no-build-isolation
```

** Point the database at SQLite** (the backend defaults to PostgreSQL on
`localhost:5432`; for local/laptop hosting without installing Postgres, SQLite is a
drop-in — the ORM has no Postgres-specific types). Create `Road-Distress-Management-System\backend\.env`:

```
DATABASE_URL=sqlite:///./road_distress.db
BACKEND_CORS_ORIGINS=*
```

** Create the tables and seed the default admin account:**

```powershell
.\.venv\Scripts\python.exe -m app.db.init_db
```

** Build the Flutter web app and Android APK** (from `mobile/`):

```powershell
cd ..\..\mobile
flutter pub get
flutter build web --release
flutter build apk --release
copy build\app\outputs\flutter-apk\app-release.apk ..\Road-Distress-Management-System\backend\uploads\RoadDistress.apk
```



** First app launch — set the connection URL once.** The native Android app has no
way to auto-detect the backend's address (that trick only works for the web build, via
the browser's origin). Open the app's connection dialog once and enter your laptop's
Wi-Fi IP (see "Getting Your Current Wi-Fi (LAN) Link" below for how to find it),
e.g. `http://192.168.1.42:8000` — it's saved on-device
afterward via `shared_preferences`, so this is a one-time step per device, not per
session. If your laptop's IP changes later (it does, on DHCP networks), re-open the
dialog and update it.

---

##  How to Start the System (Exact PowerShell Commands)

Every time you want to run the app, start these in **3 separate PowerShell windows**,
from `<path-to-repo>\Road-Distress-Management-System\backend` in each:

> ** find `<path-to-repo>` from anywhere inside the cloned folder with
> `git rev-parse --show-toplevel`.

### 1️⃣ Terminal 1 — Backend (port 8000)

```powershell
cd <path-to-repo>\Road-Distress-Management-System\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- **Backend API**: `http://127.0.0.1:8000`
- **Swagger Docs**: `http://127.0.0.1:8000/docs`
- **Auto-Seeding**: verifies/seeds demo video + detection records + reports on startup.
- Leave this window open — closing it stops the backend.

### 2️⃣ Terminal 2 — Web & Reverse Proxy (port 8080)

```powershell
cd <path-to-repo>\Road-Distress-Management-System\backend
.\.venv\Scripts\python.exe scripts\serve_no_cache.py
```

- Serves the built Flutter web app, and reverse-proxies `/api/`, `/uploads/`, and
  `/download-apk` (including WebSocket connections — live detection needs this) to
  the backend on port 8000.
- Prints your current Wi-Fi IP in its startup banner — this is also Terminal 2's job
  when you need the LAN link (see "Getting Your Current Wi-Fi (LAN) Link" below).
- **Required** for both LAN access and the public tunnel (Terminal 3 forwards *this*
  server, not the backend directly) — always start this before Terminal 3.

### 3️⃣ Terminal 3 — Public Tunnel for 4G/5G (optional)

Only needed if you want access from outside your Wi-Fi network:

```powershell
cd <path-to-repo>\Road-Distress-Management-System\backend
.\.venv\Scripts\python.exe scripts\run_stable_tunnel.py
```

- Prints a public `https://*.loca.lt` URL in its startup banner — see
  the cellular link steps below ("Getting Your Current Cellular (4G/5G) Link").
- Falls back to a Pinggy tunnel (60-minute free-tier expiry) if localtunnel is
  unreachable — the banner tells you which one you got.

---

## 🌐 Getting Your Current Wi-Fi (LAN) Link

Needed any time you connect a phone on the **same Wi-Fi** .laptop's
IP can change (DHCP renewals, reconnecting to the network) — always get the *current*
one rather than reusing an old one.

**Option A — read it from Terminal 2's banner** (simplest — it's printed automatically
every time `serve_no_cache.py` starts):
```
Local Wi-Fi Access    : http://<your-wifi-ip>:8080
```

**Option B — check it yourself in PowerShell** at any time:
```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -eq 'Wi-Fi' } | Select-Object IPAddress
```

Then, on your phone (same Wi-Fi):
- **Browser, no install**: open `http://<ip>:8080`
- **Installed APK**: open the app's connection dialog, enter `http://<ip>:8000` (port
  **8000**, not 8080 — the app talks to the backend directly, not through the proxy)

---

## 📶 Getting Your Current Cellular (4G/5G) Link

Needed for access from **outside** your Wi-Fi network (mobile data, a different network
entirely). Requires Terminal 2 *and* Terminal 3 both running — Terminal 3 only tunnels
whatever's on port 8080.

1. Start Terminal 3 (`run_stable_tunnel.py`) as shown above.
2. Read the URL from its console output:
   ```
   your url is: https://<random-words>.loca.lt
   ```
3. Open that exact URL on any device, on any network (Wi-Fi or cellular) — no app
   install needed for the web version; for the installed APK, enter that same URL
   (with `https://`) in the connection dialog.

**This URL is not permanent** — it changes every time Terminal 3 restarts (crash,
laptop sleep/wake, manual restart). If a previously-working link stops connecting,
check Terminal 3's window for whether it's still running and what URL it's currently
printing; restart it if the window closed.

**First-visit browser warning**: opening the tunnel URL directly in a phone browser
(not through the installed APK) shows a one-time localtunnel interstitial ("Tunnel
website ahead!") asking you to confirm the shown IP and click Continue — this is
localtunnel's own anti-abuse page, not an app error, and only appears once per device
per 7 days.

---

## ✅ Verifying Everything Is Running

From PowerShell, at any time:

```powershell
# Backend
Invoke-WebRequest http://127.0.0.1:8000/docs -UseBasicParsing | Select-Object StatusCode

# Proxy
Invoke-WebRequest http://127.0.0.1:8080/ -UseBasicParsing | Select-Object StatusCode

# Tunnel (replace with your current URL)
Invoke-WebRequest https://<your-tunnel-url>.loca.lt/ -UseBasicParsing -Headers @{ "Bypass-Tunnel-Reminder" = "true" } | Select-Object StatusCode
```

All three should return `StatusCode: 200`. If the backend or proxy isn't responding,
that terminal window likely closed or crashed — just re-run its start command.

---

##  Quick Access Links Summary

| Connection Type | Target Device | Access URL |
|-----------------|---------------|----------------------|
| **Local Desktop** | Laptop / PC | `http://localhost:8080` |
| **Local Wi-Fi (browser)** | Phone on same Wi-Fi | `http://<your-wifi-ip>:8080` |
| **Local Wi-Fi (installed APK)** | Phone on same Wi-Fi | `http://<your-wifi-ip>:8000` in the connection dialog |
| **Mobile Data (4G/5G)** | Any device, any network | `https://<tunnel-url>.loca.lt` |
| **Download Android APK** | Any browser | `http://<wifi-ip-or-tunnel-url>/download-apk` |

---

##  Android APK Installation Guide

The system provides a downloadable APK for native Android access with real-time push notifications and offline-capable caching.

### Step 1 — Get the Download Link
When Terminal 3 is running, your APK download link is:
```
https://<tunnel-url>.loca.lt/download-apk
```
Copy this link from the Terminal 3 console banner.

### Step 2 — Install on Android
1. Open the APK download link in your Android browser (Chrome recommended).
2. Tap the downloaded `.apk` file to install.
3. If prompted with *"Install from unknown sources"*, go to **Settings → Security → Install Unknown Apps** and enable it for your browser.
4. Open the app, then open its connection dialog and enter the backend URL — either
   `http://<your-wifi-ip>:8000` (LAN) or `https://<tunnel-url>.loca.lt` (cellular). This
   is a one-time step; the app saves it on-device and reconnects automatically after
   that, even across restarts.

### Step 3 — Rebuild the APK After Code Changes
```powershell
cd <path-to-repo>\mobile
flutter build apk --release
copy build\app\outputs\flutter-apk\app-release.apk ..\Road-Distress-Management-System\backend\uploads\RoadDistress.apk
```
The connection URL does **not** need to be baked in at build time (that's an optional
`--dart-define=API_BASE_URL=...` flag if you specifically want a default other than
the in-app dialog) — since tunnel URLs change on every restart, entering it once in
the running app is simpler than rebuilding whenever the URL changes.

---

##  Key Features Implemented

1. **Dual Video Side-by-Side Review**:
   - View raw surveillance footage alongside AI-annotated object detection feeds.
   - Synchronized timeline seeking, playback speed control, and status tracking.

2. **Independent Fullscreen Mode**:
   - Each player card has an isolated top header with its own **Fullscreen** toggle button so expanding the AI Annotated Feed does not disrupt the Original Feed.

3. **Zoomed-in AI Distress Crop Snippets (Exact Annotated Video Frames)**:
   - Detection cards display crop snippets extracted directly from the AI annotated video stream (*Potholes*, *Alligator Cracks*, *Rutting*, *Edge Breaks*).
   - Includes **`Play Clip (00:04)`** buttons that seek the video directly to that distress timestamp.

4. **PDF & Excel Report Downloads**:
   - Prominent **PDF Report** and **Excel Report** buttons generate dynamic safety audit files via FastAPI and trigger direct native JS Blob file downloads on mobile and desktop devices.

5. **Android APK (Native Mobile App)**:
   - A compiled Android APK is served directly via the `/download-apk` backend endpoint.
   - Can be shared via the public tunnel URL (`https://*.loca.lt/download-apk`) for instant installation on any Android device — no app store required.

6. **Real-Time Live Detection — USB Camera or Phone Camera**:
   - The Live Monitoring screen runs the same dual YOLOX (road + signage) pipeline against a live camera instead of an uploaded video.
   - **USB Camera** mode: a camera physically attached to whatever machine runs the backend (`app/services/live/live_camera_service.py`).
   - **This Device's Camera** mode: any phone running the app streams its own camera to the backend over WebSocket (`/api/v1/live/phone-stream`) — the right choice once the backend runs on a remote/dedicated server rather than being co-located with the camera. Detection boxes are drawn live on the phone's own camera preview as results arrive.
   - Both modes need Terminal 2 (the proxy) running, since it also proxies the WebSocket connections this feature depends on — see "Verifying Everything Is Running" above if live detection connects but shows no results.
   - **All AI processing runs on the backend machine (the laptop/server), never on the phone.** In phone-camera mode, the phone only captures frames, JPEG-encodes them, sends them over the network, and draws the returned bounding boxes on its own live preview — it never runs a model. The phone's hardware only needs to handle its camera and network I/O; all inference compute (and therefore the GPU/CPU sizing discussion elsewhere in this README) is about the backend machine, regardless of how many phones/cameras are feeding it.
   - **Live pipeline resolution differs from the video-upload pipeline**: to stay fast enough for real-time use, live detection runs both models at **256×256** (`LIVE_TEST_SIZE` in `app/services/live/live_config.py`), versus **640×640** for the offline video-upload pipeline (`app/services/ai/model_loader.py`). This is a deliberate accuracy/speed tradeoff specific to the real-time path, not a bug or inconsistency.
   - **Measured inference time at the live pipeline's actual 256×256 resolution** (same trained checkpoints, same hardware as the video-pipeline benchmarks above):

     | Model | CPU | GPU (RTX 3050, 6GB) |
     |---|---|---|
     | Road distress | 72ms | 15ms |
     | Signage | 36ms | 13ms |
     | Combined | ~108ms/frame | ~27ms/frame |

     The signage model only runs on every 3rd inference cycle (`RUN_SIGNAGE_EVERY_N_INFERENCES`), so the typical cycle cost is closer to the road-only number. These are pure model-forward times; actual detection-to-display latency also includes network transfer and JPEG encode/decode on top.

7. **GPU / Server Sizing Benchmarks** (`Road-Distress-Management-System/backend/scripts/`):
   - `benchmark_inference.py` — pure model inference timing (CPU vs GPU), using the real trained checkpoints.
   - `pipeline_profile_report.py` — full report: video specs, preprocessing details, per-model timing, and live CPU/RAM/GPU utilization, useful for sizing a dedicated server before renting/buying one.
   ```powershell
   cd <path-to-repo>\Road-Distress-Management-System\backend
   .\.venv\Scripts\python.exe scripts\pipeline_profile_report.py --frames 30 --json report.json
   ```

