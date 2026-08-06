# Deploying the Road Distress Management System as a real, hosted app

This turns what you've been running locally (`uvicorn` + `flutter run -d chrome`)
into something reachable at a real URL, running continuously on a server instead
of your own machine.

Stack: **nginx** (serves the Flutter web build, reverse-proxies API calls) →
**FastAPI backend** (AI pipeline, real inference) → **PostgreSQL**. All three run
as Docker containers defined in `Road-Distress-Management-System/docker-compose.yml`.

---

## 0. Get a server

You need a Linux server with a public IP, at least 4GB RAM (the AI models are a
few hundred MB and inference is CPU-bound without a GPU), and Docker installed.

**Recommended (genuinely free, no time limit): Oracle Cloud "Always Free" tier.**
It offers an ARM (Ampere A1) instance with up to 4 OCPUs / 24GB RAM for free
forever, which is far more headroom than typical free tiers (Render/Railway
give ~512MB, not enough for torch + OpenCV + a live pipeline).

1. Sign up at https://www.oracle.com/cloud/free/ (requires a card for identity
   verification, but the Always Free resources are never billed).
2. Create a Compute Instance: Ubuntu 22.04, shape "VM.Standard.A1.Flex" (ARM),
   4 OCPU / 24GB RAM, under the Always Free eligible list.
3. Open port 80 (and 443 if you'll add HTTPS later): Instance → attached VCN →
   Security Lists → Add Ingress Rule → Source `0.0.0.0/0`, Destination Port 80.
4. Note the instance's public IP and SSH in:
   ```
   ssh ubuntu@<your-server-ip>
   ```

If you already have a different VPS (DigitalOcean, AWS, a college server,
anything Ubuntu-based), skip to step 1 — everything below is generic.

---

## 1. Install Docker + git-lfs on the server

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 git git-lfs
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker   # re-applies the group change without a fresh login
git lfs install
```

## 2. Clone the repo and pull the model weights

```bash
git clone https://github.com/shreesh1802/Distress_management_project.git
cd Distress_management_project
git lfs pull    # downloads road_best.pth (~193MB) and signage_best.pth (~68.5MB)
```

## 3. Install Flutter and build the web app

The frontend is built once into static files; nginx just serves them (no
Flutter/Dart runtime needed on the server after this step).

```bash
sudo snap install flutter --classic    # or follow flutter.dev's Linux install docs
cd mobile
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=http://<your-server-ip>
cd ..
```

Replace `<your-server-ip>` with the real public IP (or domain, once you have
one — see step 6). This is the one setting that tells the app where its own
backend lives; everything else (WebSocket URL, all API calls) derives from it
automatically.

## 4. Start everything

```bash
cd Road-Distress-Management-System
docker compose up -d --build
```

First build takes a while (torch + opencv + yolox compile). Watch progress with:
```bash
docker compose logs -f backend
```

## 5. Create the database tables + admin login (one-time)

```bash
docker compose exec backend python -m app.db.init_db
```

This creates all tables and seeds a default admin account:
- **Email:** `admin@roaddistress.org`
- **Password:** `AdminSecurePassword123!`

**Log in and change this password immediately** — it's a well-known default
sitting in the repo's source code, not a secret.

## 6. Verify

Open `http://<your-server-ip>` in a browser. You should see the login screen.
Check the backend directly at `http://<your-server-ip>/api/v1/docs` (or
whatever path FastAPI's OpenAPI docs are mounted at) to confirm it's reachable.

Try a full round trip: log in, upload a short video, confirm it processes and
Video Review shows real detections — the same thing we verified locally, now
running on the server instead of your machine.

---

## Updating after future code changes

```bash
cd Distress_management_project
git pull origin claude/flutter-web-dashboard-port-i2qcj3   # or main, once merged

# backend changed:
cd Road-Distress-Management-System
docker compose up -d --build backend

# frontend changed:
cd ../mobile
flutter build web --release --dart-define=API_BASE_URL=http://<your-server-ip>
# nginx serves the build/ folder directly (bind-mounted) -- no restart needed,
# just refresh the browser.
```

---

## Optional: a real domain + HTTPS

A bare IP works, but a domain name is more presentable and lets you add
HTTPS (browsers increasingly restrict things like WebSocket/getUserMedia to
secure origins, relevant if the live-camera feature is used).

1. Buy/point a domain's A record at your server's IP.
2. Rebuild the frontend with the domain instead of the IP:
   ```bash
   flutter build web --release --dart-define=API_BASE_URL=https://your-domain.com
   ```
3. Install certbot and get a free Let's Encrypt certificate:
   ```bash
   sudo apt-get install -y certbot python3-certbot-nginx
   ```
   Since nginx runs inside Docker here rather than natively, the simplest path
   is `certbot certonly --standalone` (stop the nginx container briefly while
   it validates), then mount the resulting cert files into the nginx
   container and add a `listen 443 ssl;` server block to
   `nginx/nginx.conf` pointing at them. Ask if you want this wired up — it's
   a small, concrete addition once you actually have a domain pointed at the
   server.

---

## What this does NOT cover

- **Backups.** The `postgres_data` Docker volume holds all your data — set up
  a periodic `pg_dump` if this stops being a throwaway pilot.
- **Resource limits under heavy concurrent video processing.** The AI
  pipeline runs synchronously per video on CPU; multiple simultaneous uploads
  will queue behind each other, not run in parallel, on a single server.
- **A CI/CD pipeline.** Deploys above are manual (`git pull` + rebuild). Fine
  for a pilot; worth automating (GitHub Actions → SSH deploy) once this is a
  real production system with frequent updates.
