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
│   └── build/web/                         # Compiled Production Web Assets
│
└── Road-Distress-Management-System/
    └── backend/                            # FastAPI AI Backend & Database
        ├── app/
        │   ├── main.py                     # FastAPI Application Entry, CORS & Auto-Seeding
        │   ├── api/v1/routes/              # API Route Handlers (videos, detection, reports)
        │   ├── models/                     # SQLAlchemy Models (distress.py, video.py, report.py)
        │   └── services/                   # PDF & Excel Generators, AI Pipeline Utils
        └── uploads/                        # Raw Videos, Processed Videos & AI Crop Images
            ├── videos/                     # Raw surveillance MP4 files (+faststart H.264)
            ├── processed/                  # AI annotated MP4 files (H.264)
            └── crops/                      # Zoomed-in AI distress crop image snippets
```

---

## ⚙️ How to Start the System (Exact Terminal Commands)

To make both the mobile/web frontend and backend fully operational, execute these **3 terminal commands**:

### 1️⃣ Terminal 1: Start FastAPI Backend Server (Port 8000)
Open PowerShell / CMD:
```powershell
cd c:\Users\0095\GitHub\Distress_management_project\Road-Distress-Management-System\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```
- **Backend API**: `http://127.0.0.1:8000`
- **Swagger Docs**: `http://127.0.0.1:8000/docs`
- **Auto-Seeding**: Automatically verifies and seeds Video 20, 8 road distress detection records, and audit reports on startup.

---

### 2️⃣ Terminal 2: Start Multithreaded Web & Proxy Server (Port 8080)
Open a second PowerShell / CMD window:
```powershell
cd c:\Users\0095\GitHub\Distress_management_project\Road-Distress-Management-System\backend
.\.venv\Scripts\python.exe C:\Users\0095\.gemini\antigravity\brain\ce728cc7-11e1-4296-81fe-cb95c880af10\scratch\serve_no_cache.py
```
- **Local Desktop Access**: `http://localhost:8080`
- **Wi-Fi Mobile Access**: `http://<your-active-wifi-ip>:8080` (Automatically auto-detected and printed in the console banner)
- **Reverse Proxy**: Automatically proxies `/api/` database requests and `/uploads/` video media to port 8000 with multithreaded socket isolation.

---

### 3️⃣ Terminal 3: Start Public Mobile Tunnel (For 4G / 5G Cellular Data)
Open a third PowerShell / CMD window:
```powershell
cd c:\Users\0095\GitHub\Distress_management_project\Road-Distress-Management-System\backend
.\.venv\Scripts\python.exe C:\Users\0095\.gemini\antigravity\brain\ce728cc7-11e1-4296-81fe-cb95c880af10\scratch\run_stable_tunnel.py
```
- **Public Mobile HTTPS URL**: Prints a zero-password `https://*.loca.lt` link.
- **Cellular Access**: Open this link in any browser on 4G / 5G mobile data or outside the local Wi-Fi network.

---

## 📱 Quick Access Links Summary

| Connection Type | Target Device | Access URL / Command |
|-----------------|---------------|----------------------|
| **Local Desktop** | Laptop / PC | `http://localhost:8080` |
| **Local Wi-Fi** | iPhone / Android on Wi-Fi | `http://<your-wifi-ip>:8080` *(See Terminal 2 banner)* |
| **Mobile Data (4G/5G)** | Any Smartphone | `https://*.loca.lt` *(See Terminal 3 banner)* |

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
