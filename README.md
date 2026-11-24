# Road Distress Management System & Mobile Web Platform

An AI-assisted pavement inspection platform. A Flutter app (Android, iOS, web) and a FastAPI backend run
two YOLOX models (road distress + signage) over uploaded survey videos **and live camera feeds**, then turn
the detections into maps, maintenance plans and PDF / Excel reports that follow the Indian repair codes
(IRC:82-2015 and IRC:SP:83-2018).

**Current release:** app version `1.1.1+3`, Android application ID `com.distress.roadmanager`
(the "Pavement Health Monitor (Early Access)" Play app).

## What's new

| Area | What changed |
|---|---|
| Sign-in | **Google sign-in via Firebase.** Only people on the Firestore `allowedUsers` allow-list (role: `admin`, `inspector`, `employee`, `maintenance`) get in. The old e-mail one-time-code login was removed. |
| Hosted server | Release builds talk to the hosted backend (Railway) by default - no connection dialog needed. Local servers are still supported (see below). |
| Live detection quality | Phone live mode looks at **every** frame it receives (no more skipped frames), and the server acknowledges each frame so the app never queues stale pictures on a slow connection. Live inference runs at 256 px by default (`LIVE_TEST_SIZE` raises it). |
| Camera picker | In *This Device's Camera* mode the app lists every camera the phone reports (front, back, external USB when the OS exposes it) in a **Camera** drop-down with a refresh button. External > back > front is the default. |
| Real GPS | Phone live sessions stream the phone's **GPS position**, so detections are stamped with where they really happened (falls back to a default point if location is off). |
| Full-screen live view | Video-call style full screen with auto-hiding controls, landscape lock and a **screen that stays awake** in the installed app. Video review also has a proper full-screen mode. |
| Field notes | While a live session runs, add a **snapshot** and / or a **voice note** (optional caption) for something the AI missed. Notes appear in the session's PDF ("Surveyor Field Notes") and Excel ("Field Notes" sheet). Voice notes are transcribed in the background when speech-to-text is available. |
| History | A *Live detection sessions* card lists past live sessions with duration, detections, serious detections, notes and PDF / Excel buttons. |
| Reports | Every report includes a **Recommended Repair Strategies** section (PDF) / sheet (Excel) from IRC:82-2015 (bituminous, default) or IRC:SP:83-2018 (concrete). Choose the pavement type under *Reports > Configure AI Reports Compilation*. See [`docs/REPAIR_STRATEGIES.md`](docs/REPAIR_STRATEGIES.md). |
| Security hardening | Hashed 30-day session tokens, allow-list re-check on every request and live WebSocket, rate limits, signed report-download links, fail-closed production config, in-app *Delete account*. See [`SECURITY.md`](SECURITY.md). |

---

##  Repository Code Architecture

```
Distress_management_project/
├── mobile/                                  # Flutter app (Android, iOS, web, desktop)
│   ├── lib/
│   │   ├── main.dart                        # Entrypoint, Firebase init, theme
│   │   ├── firebase_options.dart            # Firebase project configuration
│   │   ├── router/app_router.dart           # GoRouter navigation + auth redirect
│   │   ├── data/                            # API clients & models
│   │   │   ├── auth_api.dart, auth_provider.dart   # Google sign-in -> /auth/google session
│   │   │   ├── live_detection_api.dart      # API base URL (hosted default), live WebSocket client
│   │   │   ├── field_notes_api.dart         # Snapshot / voice field notes
│   │   │   ├── live_sessions_api.dart       # Past live sessions (History)
│   │   │   └── video_api.dart, reports_api.dart, road_distress_api.dart, ...
│   │   ├── screens/
│   │   │   ├── login/                       # Google sign-in screen
│   │   │   ├── projects/, survey/, asset/, audit/   # Projects, surveys, assets, audits
│   │   │   ├── dashboard/, dashboard_grid/  # Shell, drawer/navigation, overview
│   │   │   ├── live_detection/              # Live monitoring: USB / phone camera, camera picker,
│   │   │   │                                #   GPS banner, full screen, field notes
│   │   │   ├── upload_video/, video_review/ # Upload + dual (original / AI) player + detections
│   │   │   ├── road_distresses/, gis_map/, maintenance/, analytics/
│   │   │   ├── reports/                     # PDF / Excel generation, pavement-type selector
│   │   │   ├── history/                     # Timeline + live session list
│   │   │   └── notifications/, account/     # Notifications, delete-account dialog
│   │   └── utils/                           # Landscape full screen, screen-awake, voice recorder /
│   │                                        #   player, report share, downloads
│   ├── android/, ios/, web/ ...             # Platform projects
│   ├── ANDROID_RELEASE.md                   # Play Store build + signing steps
│   └── test/                                # Widget / unit tests
│
├── Road-Distress-Management-System/
│   ├── backend/                             # FastAPI AI backend
│   │   ├── app/
│   │   │   ├── main.py                      # App entry, CORS, startup checks
│   │   │   ├── api/v1/routes/               # auth, users, projects, assets, audits, videos, upload,
│   │   │   │                                #   detection, distress, live, observations (field notes),
│   │   │   │                                #   reports, maintenance, gis
│   │   │   ├── models/                      # SQLAlchemy models
│   │   │   └── services/
│   │   │       ├── ai/                      # Road + signage detectors, tracker, pipeline
│   │   │       ├── live/                    # Live camera service, live_config.py, YOLOX engine
│   │   │       ├── firebase_service.py      # Verifies Firebase ID tokens, reads the allow-list
│   │   │       ├── repair_strategies.py     # IRC:82 / IRC:SP:83 repair guidance
│   │   │       ├── pdf_generator.py, excel_generator.py, field_notes_report.py
│   │   │       └── transcription_service.py # Voice-note speech-to-text (optional)
│   │   ├── tests/                           # Backend tests (tests/security = security suite)
│   │   ├── scripts/                         # serve_no_cache.py, run_stable_tunnel.py, benchmarks
│   │   ├── local.env.example                # Settings for running on your own computer
│   │   └── railway.env.example              # Settings for the hosted server
│   ├── docker-compose.yml, nginx/           # Self-hosted Docker deployment (see DEPLOYMENT.md)
│   └── frontend/                            # Original React app, kept as a design reference
│
├── docs/                                    # REPAIR_STRATEGIES.md, live-detection hosting notes, privacy pages
├── scripts/security_check.py                # Static security check
└── SECURITY.md, DEPLOYMENT.md, WORKFLOW_ANALYSIS.md
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

** Point the database at SQLite and give the backend your Firebase key** (the backend defaults to
PostgreSQL on `localhost:5432`; for local/laptop hosting without installing Postgres, SQLite is a
drop-in). Copy `Road-Distress-Management-System\backend\local.env.example` to `.env` in the same folder and
adjust it. The essentials are:

```
DATABASE_URL=sqlite:///./road_distress.db
BACKEND_CORS_ORIGINS=*
FIREBASE_CREDENTIALS_PATH=C:/keys/road-distress-firebase-adminsdk.json
```

`FIREBASE_CREDENTIALS_PATH` points at the Firebase **service-account key** (Firebase console > Project
settings > Service accounts > *Generate new private key*). It is a secret: keep it outside the repository and
never commit it. The backend uses it to verify Google sign-ins and to read the `allowedUsers` allow-list.

** Create the tables:**

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

** Signing in.** Add your Google e-mail to the Firestore collection `allowedUsers` (document ID = your
lower-case e-mail, field `role` = `admin`, `inspector`, `employee` or `maintenance`) in the Firebase console, then
sign in with that Google account. There is no self-registration and no e-mail-code login - see `SECURITY.md`.

** Which server does the app talk to?**

* **Release builds** (`flutter build apk --release`, app bundles) use the hosted server
  (`kProductionApiBaseUrl` in `mobile/lib/data/live_detection_api.dart`) automatically.
* To point a build at **your own laptop / another server**, pass the address at build time:
  `flutter build apk --release --dart-define=API_BASE_URL=http://<your-wifi-ip>:8000`
  (use `https://<tunnel-url>` for the tunnel). Debug builds and the web build served by Terminal 2 detect the
  backend from the page's address, so they need nothing.
* **Android Google sign-in** only works for APKs signed with a key whose SHA-1 / SHA-256 fingerprints are
  registered for the Android app in the Firebase console (otherwise `DEVELOPER_ERROR`). A
  `flutter build apk --release` without `android/key.properties` is signed with the local debug key, which
  must be registered too.

---

##  How to Start the System (Exact PowerShell Commands)

Every time you want to run the app locally, start these in **3 separate PowerShell windows**,
from `<path-to-repo>\Road-Distress-Management-System\backend` in each (Terminal 3 is optional):

> ** find `<path-to-repo>` from anywhere inside the cloned folder with
> `git rev-parse --show-toplevel`.

### 1️⃣ Terminal 1 — Backend (port 8000)

```powershell
cd <path-to-repo>\Road-Distress-Management-System\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- **Backend API**: `http://127.0.0.1:8000`
- **Swagger Docs**: `http://127.0.0.1:8000/docs` (development mode only)
- **Auto-Seeding**: in development mode, verifies/seeds demo video + detection records + reports on startup.
- Leave this window open — closing it stops the backend.
- The hosted server (Railway) runs the same backend with `APP_ENV=production`; see `SECURITY.md` and
  `backend/railway.env.example`.

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

Needed any time you connect a phone on the **same Wi-Fi**. The laptop's
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
- **APK built for your laptop** (`--dart-define=API_BASE_URL=http://<ip>:8000`): port
  **8000**, not 8080 — the app talks to the backend directly, not through the proxy

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
   install needed for the web version.

**This URL is not permanent** — it changes every time Terminal 3 restarts (crash,
laptop sleep/wake, manual restart). If a previously-working link stops connecting,
check Terminal 3's window for whether it's still running and what URL it's currently
printing; restart it if the window closed.

**First-visit browser warning**: opening the tunnel URL directly in a phone browser
shows a one-time localtunnel interstitial ("Tunnel website ahead!") asking you to
confirm the shown IP and click Continue — this is localtunnel's own anti-abuse page,
not an app error, and only appears once per device per 7 days.

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
| **Hosted server** | Any device | the Railway URL in `kProductionApiBaseUrl` (release builds use it automatically) |
| **Local Desktop** | Laptop / PC | `http://localhost:8080` |
| **Local Wi-Fi (browser)** | Phone on same Wi-Fi | `http://<your-wifi-ip>:8080` |
| **Local Wi-Fi (APK)** | Phone on same Wi-Fi | APK built with `API_BASE_URL=http://<your-wifi-ip>:8000` |
| **Mobile Data (4G/5G)** | Any device, any network | `https://<tunnel-url>.loca.lt` |
| **Download Android APK** | Any browser | `http://<wifi-ip-or-tunnel-url>/download-apk` |

---

##  Android APK Installation Guide

### Build an APK to test the latest features

```powershell
cd <path-to-repo>\mobile
flutter pub get
flutter build apk --release
```

Output: `mobile\build\app\outputs\flutter-apk\app-release.apk`. Copy it to the phone (USB, Drive, ...) and open it;
allow *Install unknown apps* for the app you opened it from if Android asks. Without `android/key.properties`
the APK is signed with the debug key — fine for testing on your own phone, but that key's fingerprints must be
registered in Firebase for Google sign-in to work (see above). Play Store bundles: see `mobile/ANDROID_RELEASE.md`.

### Serving the APK from your own backend (optional)

```powershell
copy build\app\outputs\flutter-apk\app-release.apk ..\Road-Distress-Management-System\backend\uploads\RoadDistress.apk
```

It is then downloadable at `http://<wifi-ip-or-tunnel-url>/download-apk`.

### Testing the live camera on Android

1. Open **Live Monitoring** and choose **This Device's Camera**.
2. Pick a camera in the **Camera** drop-down (tap the refresh icon after plugging in a USB camera — it only
   appears if Android exposes it as an external camera).
3. Allow camera, microphone (voice notes) and location (GPS) when asked, then **Start**.
4. Use the expand button for full screen, and the Field Notes card to add snapshots / voice notes.

---

##  Key Features Implemented

1. **Dual Video Side-by-Side Review**:
   - View raw surveillance footage alongside AI-annotated object detection feeds.
   - Synchronized timeline seeking, playback speed control, and status tracking.

2. **Independent & Full-Screen Modes**:
   - Each player card has its own **Fullscreen** toggle so expanding the AI Annotated Feed does not disrupt the Original Feed.
   - Video review has a full-screen layout that hides the dashboard menus (side by side when sideways, stacked when upright).

3. **Zoomed-in AI Distress Crop Snippets (Exact Annotated Video Frames)**:
   - Detection cards display crop snippets extracted directly from the AI annotated video stream (*Potholes*, *Alligator Cracks*, *Rutting*, *Edge Breaks*).
   - Includes **`Play Clip (00:04)`** buttons that seek the video directly to that distress timestamp.

4. **PDF & Excel Report Downloads**:
   - **PDF Report** and **Excel Report** buttons generate dynamic safety-audit files via FastAPI and trigger native downloads / sharing on mobile and desktop.
   - Reports include IRC repair strategies (bituminous or concrete pavement) and, for live sessions, the surveyor's field notes.

5. **Android App**:
   - Google sign-in, projects / surveys / assets / audits, upload, live detection, maps, maintenance and reports in one app (also built for iOS and web).
   - Release builds use the hosted server; an APK can also be sideloaded or served via the backend's `/download-apk` endpoint.

6. **Real-Time Live Detection — USB Camera or Phone Camera**:
   - The Live Monitoring screen runs the same dual YOLOX (road + signage) pipeline against a live camera instead of an uploaded video.
   - **USB Camera** mode: a camera physically attached to whatever machine runs the backend (`app/services/live/live_camera_service.py`).
   - **This Device's Camera** mode: any phone running the app streams its own camera to the backend over WebSocket (`/api/v1/live/phone-stream`) — the right choice once the backend runs on a remote/dedicated server rather than being co-located with the camera. Detection boxes are drawn live on the phone's own camera preview as results arrive. A **Camera** drop-down lets you pick which camera to use.
   - Both modes need Terminal 2 (the proxy) running when you host locally, since it also proxies the WebSocket connections this feature depends on — see "Verifying Everything Is Running" above if live detection connects but shows no results.
   - **All AI processing runs on the backend machine (the laptop/server), never on the phone.** In phone-camera mode, the phone only captures frames, JPEG-encodes them, sends them over the network, and draws the returned bounding boxes on its own live preview — it never runs a model.
   - **Phone-mode flow control**: the app sends frames as fast as the connection carries them (about 10 captures a second at most), the server runs detection on every frame it receives (`LIVE_REMOTE_PROCESS_EVERY_N_FRAMES`, default 1) and acknowledges each one, and the app never keeps more than 2 frames un-acknowledged — a slow connection lowers the frame rate instead of building a queue of stale pictures.
   - **Real GPS**: the phone's position is sent over the same WebSocket (`{"type":"location",...}` messages, roughly every 2 s) and used to stamp detections while it is fresher than `LIVE_DEVICE_FIX_MAX_AGE` (default 15 s); otherwise the configured default point is used. `/live/status` reports `gps_source` (`device` or `default`).
   - **Field notes**: snapshot and voice notes for a live session (`/observations/...`), shown in the session's reports and under History.
   - **Live pipeline resolution**: live detection runs at **256×256** by default (`LIVE_TEST_SIZE` in `app/services/live/live_config.py`) versus **640×640** for the offline video-upload pipeline, to keep detections arriving in real time. Higher sizes catch more (recall was roughly 22% at 256 vs 45-50% at 640 on dashcam footage) but cost several times the inference time on a CPU, so raise it (e.g. `LIVE_TEST_SIZE=416` or `640`) only on a GPU or a fast host.
   - **Measured inference time at 256×256** (the default; expect several times more at 640), same trained checkpoints, same hardware as the video-pipeline benchmarks:

     | Model | CPU | GPU (RTX 3050, 6GB) |
     |---|---|---|
     | Road distress | 72ms | 15ms |
     | Signage | 36ms | 13ms |
     | Combined | ~108ms/frame | ~27ms/frame |

     The signage model only runs on every 3rd inference cycle (`RUN_SIGNAGE_EVERY_N_INFERENCES`), so the typical cycle cost is closer to the road-only number. These are pure model-forward times; actual detection-to-display latency also includes network transfer and JPEG encode/decode on top.

7. **Field Notes (snapshots & voice notes)**: add evidence for what the AI missed during a live session. Notes are stored with the session, included in its PDF ("Surveyor Field Notes") and Excel ("Field Notes" sheet) reports, and listed under **History > Live detection sessions**. Voice notes are validated (type, content, 25 MB limit) and transcribed in the background when speech-to-text is installed; reports never fail because of a notes problem.

8. **Repair Strategies in Reports**: PDF *Recommended Repair Strategies* section and Excel *Repair Strategies* sheet per distress type and severity, following IRC:82-2015 (bituminous, default) or IRC:SP:83-2018 (concrete). Details in `docs/REPAIR_STRATEGIES.md`.

9. **Access Control & Security**: Google sign-in with a Firestore allow-list, role-based access, hashed expiring sessions, rate limits, signed download links, and an in-app *Delete account*. Run the safeguards with `python -m pytest tests/security` (from the backend folder) and `python scripts/security_check.py`; see `SECURITY.md`.

10. **Hosted Deployment**: the backend runs on Railway (settings template: `backend/railway.env.example`) with PostgreSQL; a self-hosted Docker + nginx option is described in `DEPLOYMENT.md`.

11. **GPU / Server Sizing Benchmarks** (`Road-Distress-Management-System/backend/scripts/`):
   - `benchmark_inference.py` — pure model inference timing (CPU vs GPU), using the real trained checkpoints.
   - `pipeline_profile_report.py` — full report: video specs, preprocessing details, per-model timing, and live CPU/RAM/GPU utilization, useful for sizing a dedicated server before renting/buying one.
   ```powershell
   cd <path-to-repo>\Road-Distress-Management-System\backend
   .\.venv\Scripts\python.exe scripts\pipeline_profile_report.py --frames 30 --json report.json
   ```

---

##  Tests

```powershell
# Flutter app
cd <path-to-repo>\mobile
flutter analyze --no-fatal-infos
flutter test

# Backend (runs against a temporary SQLite database)
cd <path-to-repo>\Road-Distress-Management-System\backend
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m pytest tests
```
