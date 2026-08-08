# Road Distress Management System & Mobile Web Platform

A production-ready, cross-platform Road Distress Detection & Inspection Management Platform. The system consists of a **FastAPI AI Backend** and a **Flutter Web/Mobile Frontend App** supporting real-time live monitoring, dual-video inspection reviews, AI distress visual crops, GIS mapping, and dynamic PDF & Excel safety audit report generation.

---

## 🏗️ Repository Code Architecture (For Developers & LLMs)

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

## ⚙️ How to Start the System (Exact Terminal Commands)

To make both the mobile/web frontend and backend fully operational, execute these **3 terminal commands** — each in a **separate PowerShell / Terminal window**:

### 1️⃣ Terminal 1 — Start FastAPI Backend Server (Port 8000)

```powershell
cd <path-to-repo>\Road-Distress-Management-System\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

> **Tip**: To find `<path-to-repo>`, run `git rev-parse --show-toplevel` from anywhere inside the cloned folder.

- **Backend API**: `http://127.0.0.1:8000`
- **Swagger Docs**: `http://127.0.0.1:8000/docs`
- **APK Download**: `http://127.0.0.1:8000/download-apk`
- **Auto-Seeding**: Automatically verifies and seeds Video 20, 8 road distress detection records, and audit reports on startup.

---

### 2️⃣ Terminal 2 — Start Multithreaded Web & Proxy Server (Port 8080)

```powershell
cd <path-to-repo>\Road-Distress-Management-System\backend
.\.venv\Scripts\python.exe scripts\serve_no_cache.py
```

- **Local Desktop Access**: `http://localhost:8080`
- **Wi-Fi Mobile Access**: `http://<your-wifi-ip>:8080` *(auto-detected — shown in the console banner)*
- **APK Download (LAN)**: `http://<your-wifi-ip>:8080/download-apk`
- **Reverse Proxy**: Automatically proxies `/api/`, `/uploads/`, and `/download-apk` to port 8000.

---

### 3️⃣ Terminal 3 — Start Public Mobile Tunnel (For 4G / 5G Cellular Data)

```powershell
cd <path-to-repo>\Road-Distress-Management-System\backend
.\.venv\Scripts\python.exe scripts\run_stable_tunnel.py
```

- **Public Mobile HTTPS URL**: Prints a zero-password `https://*.loca.lt` link in the console banner.
- **Cellular Access**: Open the `*.loca.lt` URL in any browser on 4G / 5G mobile data — works outside the local Wi-Fi network.
- **APK Download (Public)**: `https://<your-tunnel-url>.loca.lt/download-apk`

---

## 📱 Quick Access Links Summary

| Connection Type | Target Device | Access URL / Command |
|-----------------|---------------|----------------------|
| **Local Desktop** | Laptop / PC | `http://localhost:8080` |
| **Local Wi-Fi** | iPhone / Android on Wi-Fi | `http://<your-wifi-ip>:8080` *(See Terminal 2 banner)* |
| **Mobile Data (4G/5G)** | Any Smartphone | `https://*.loca.lt` *(See Terminal 3 banner)* |
| **Download Android APK** | Android Phone | `https://<tunnel-url>.loca.lt/download-apk` |

> **Note on Tunnel URLs**: localtunnel URLs are temporary and change every time Terminal 3 is restarted. Always look at the banner printed in Terminal 3 for the current active URL.

---

## 📲 Android APK Installation Guide

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
4. Open the app — it will automatically connect to the backend via the public tunnel URL.

### Step 3 — Build a New APK (For Developers)
To rebuild the APK with a new tunnel URL baked in:
```powershell
cd <path-to-repo>\mobile
flutter build apk --release --dart-define=API_BASE_URL=https://<your-tunnel-url>.loca.lt
```
The built APK will be at: `mobile\build\app\outputs\flutter-apk\app-release.apk`

---

## 🔥 Key Features Implemented

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

