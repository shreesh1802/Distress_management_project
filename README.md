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
│   │   ├── router/app_router.dart          # GoRouter Navigation Setup (Bypasses auth for demo)
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
│   └── build/web/                         # Compiled Production Web Assets
│
└── Road-Distress-Management-System/
    └── backend/                            # FastAPI AI Backend & Database
        ├── app/
        │   ├── main.py                     # FastAPI Application Entry & CORS Setup
        │   ├── api/v1/routes/              # API Route Handlers (videos, detection, reports)
        │   ├── models/                     # SQLAlchemy Models (distress.py, video.py, report.py)
        │   └── services/                   # PDF & Excel Generators, AI Pipeline Utils
        └── uploads/                        # Raw Videos, Processed Videos & AI Crop Images
            ├── videos/                     # Raw surveillance MP4 files (+faststart optimized)
            ├── processed/                  # AI annotated MP4 files
            └── crops/                      # Zoomed-in AI distress crop image snippets
```

---

## ⚙️ How to Start the System (Required Servers)

To make both the frontend and backend fully operational, **start these 2 processes**:

### 1. Start FastAPI Backend Server (Port 8000)
From `Road-Distress-Management-System/backend`:
```bash
cd Road-Distress-Management-System/backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```
- **Backend API**: `http://127.0.0.1:8000`
- **Swagger Docs**: `http://127.0.0.1:8000/docs`

### 2. Start Web & API Proxy Server (Port 8080)
From repository root:
```bash
python scratch/serve_no_cache.py
```
- **Web App**: `http://127.0.0.1:8080` or `http://<your-local-ip>:8080`
- **Reverse Proxy**: Automatically proxies `/api/` database calls and `/uploads/` media requests to port 8000, preventing CORS and Mixed Content issues on mobile viewports.

---

## 📱 How to Access & Demonstrate on Mobile Devices

### Method A: Local Wi-Fi Connection (Recommended — Fast & 0 Setup)
1. Ensure your mobile phone (iPhone or Android) is connected to the **same Wi-Fi network** as the host laptop.
2. Open your mobile browser (Safari or Chrome) and navigate to:
   ```
   http://172.16.211.117:8080
   ```
3. The app will load instantly with **zero password required**.

### Method B: Public Internet Access (4G / 5G Mobile Data)
If accessing remotely over mobile cellular data:
```bash
npx localtunnel --port 8080
```
- Enter the generated `loca.lt` URL in your mobile browser.
- When prompted for the Tunnel Password, enter the host's public IP address.

---

## 🔥 Key Features Implemented

1. **Dual Video Side-by-Side Review**:
   - View raw surveillance footage alongside AI-annotated object detection feeds.
   - Synchronized timeline seeking, playback speed control, and status tracking.

2. **Independent Fullscreen Mode**:
   - Each player card has an isolated top header with its own **Fullscreen** toggle button so expanding the AI Annotated Feed does not disrupt the Original Feed.

3. **Zoomed-in AI Distress Crop Snippets**:
   - Detections cards feature visual crop image snippets zoomed in directly on road surface distresses (*Potholes*, *Alligator Cracks*, *Rutting*, *Edge Breaks*).
   - Includes **`Play Clip (00:04)`** buttons that seek the video directly to that distress timestamp.

4. **PDF & Excel Report Downloads**:
   - Prominent **PDF Report** and **Excel Report** buttons generate dynamic safety audit files via FastAPI and trigger direct native JS Blob file downloads on mobile and desktop devices.
