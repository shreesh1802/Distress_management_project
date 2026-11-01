# 01 — Attacker (Red-Team) Report

**Scope:** static, read-only, white-box review of `Distress_management_project` (backend, Flutter app, legacy React frontend, Docker, scripts, full git history). No code was run, no network calls were made, nothing was modified.
**Baseline commit:** `0521a84` (working tree clean before and after the run).
**Status:** UNVERIFIED claims at the time of writing. See `02_SUPERVISOR_REPORT.md` for which findings were confirmed against the code.
**Note:** the attack-chains section was intentionally omitted (the agent's output filter cut it off twice; per-finding fix and verification steps cover what the defender needs).
Paths are relative to `Road-Distress-Management-System/backend/` unless prefixed `mobile/`, `frontend/`, `scripts/`.

## 1. Executive summary

**Overall risk: CRITICAL.** The new OTP / Projects / Audit / Asset layer is mostly sound (project-membership checks are correct), but it sits beside a legacy backend with no authentication, open account creation and open user management. Login has no secure production configuration: dev-mode OTP is the default and the real email sender is a stub.

Counts: Critical 5, High 6, Medium 11, Low 6, Info 2 (30 total).

Top fixes before Play Store submission:
1. Authenticate and authorize every route (global `get_current_user`, `require_admin` for user management; remove/lock `users.py` and role self-assignment in `/auth/register`) — ATK-001, 002, 005.
2. Make login real: email delivery, remove `dev_otp` from responses/logs, use `secrets`, cap attempts per email, rate-limit, one active code — ATK-003, 006.
3. Remove client-controlled filesystem paths: stop accepting `filepath` / `processed_filepath` from clients; confine every `FileResponse` and `os.remove` to the uploads root; serve uploads through authenticated routes — ATK-004, 009.
4. Fix the Android build: remove `badCertificateCallback => true`, disable cleartext, real `applicationId` and release keystore, `network_security_config`, `allowBackup=false`, secure token storage — ATK-007, 011, 012.
5. Lock down `/live/*`, add limits, fix the session-stop bug — ATK-008, 010.

## 2. Findings table

| ID | Sev | Score | Title | Location | Category |
|---|---|---|---|---|---|
| ATK-001 | Critical | 9.8 | Unauthenticated user-management API | app/api/v1/routes/users.py:15-58 | AuthZ |
| ATK-002 | Critical | 9.1 | /auth/register accepts client-chosen role | routes/auth.py:48-59; schemas/user.py:24 | AuthZ |
| ATK-003 | Critical | 9.8 | OTP returned and logged; dev mode default; no working prod mode | routes/auth.py:68,84; services/otp_service.py:32,51-53,59-64 | Auth |
| ATK-004 | Critical | 9.1 | Client-controlled file paths reach file read and delete | routes/upload.py:53-86; routes/videos.py:99-175; services/video.py:175-193 | Input |
| ATK-005 | Critical | 9.1 | Legacy M1 routes have no authentication | routes/{videos,upload,distress,gis,reports,maintenance,detection,live}.py | AuthZ |
| ATK-006 | High | 8.1 | OTP guessing protections missing; weak PRNG | services/otp_service.py:17,35-36,67-84 | Auth |
| ATK-007 | High | 7.4 | TLS validation disabled in app | mobile/lib/data/http_overrides_io.dart:11-14; main.dart:12 | Transport |
| ATK-008 | High | 7.5 | Live/WebSocket endpoints unauthenticated; session-stop bug | routes/live.py:41-191 | AuthZ/DoS |
| ATK-009 | High | 7.5 | Public /uploads mount bypasses ACLs | app/main.py:298-316 | AuthZ |
| ATK-010 | High | 7.5 | Unauthenticated resource exhaustion, no rate limits | routes/videos.py:23-36; detection.py; reports.py; auth.py:34-45 | DoS |
| ATK-011 | High | 7.0 | Android release config not secure / Play-eligible | mobile/android/app/build.gradle.kts:19,30-32; AndroidManifest.xml:9 | Mobile |
| ATK-012 | Medium | 6.5 | Session token lifecycle weaknesses | otp_service.py:87-103; mobile auth_provider.dart:46,105,124 | Session |
| ATK-013 | Medium | 5.3 | User enumeration | auth.py:53-58,80-84; users.py:25-32 | Auth |
| ATK-014 | Medium | 5.4 | Thin authorization model | core/deps.py:30-33; crud/project.py:24-45 | AuthZ |
| ATK-015 | Medium | 5.9 | CORS *, HTTP-only, no headers, OpenAPI exposed | main.py:33-39; nginx/nginx.conf; DEPLOYMENT.md | Transport |
| ATK-016 | Medium | 5.3 | Known default credentials; plaintext-hash fallback | main.py:161; core/security.py:16-18; db/init_db.py:78 | Secrets |
| ATK-017 | Medium | 5.3 | Verbose errors / info disclosure | main.py:262; reports.py:72,107; videos.py:117-121,154-158 | Info leak |
| ATK-018 | Medium | 5.5 | Docker: root, local files baked in, default DB creds | Dockerfile:33; .dockerignore; docker-compose.yml:9,28 | Supply chain |
| ATK-019 | Medium | 5.3 | ReportLab markup injection | services/pdf_generator.py:163,354-374 | Injection |
| ATK-020 | Medium | 5.0 | Silent MockYOLO fallback fabricates detections | services/ai/model_loader.py:135-170,251-254,295-298 | Integrity |
| ATK-021 | Medium | 4.8 | App trusts server-supplied URLs; backend-URL override | mobile video_review_screen.dart:152,158; gis_api.dart:107; dashboard_shell.dart:13-66 | Mobile |
| ATK-022 | Medium | 4.4 | Dev tooling supply chain | scripts/run_stable_tunnel.py:16-17,50; scripts/cloudflared.exe | Supply chain |
| ATK-023 | Low | 4.3 | Upload validation extension-only | services/{video,audit,asset}.py; transcription_service.py:72 | Input |
| ATK-024 | Low | 4.0 | Unsafe deserialization settings | services/live/yolox_engine.py:77,94 | Deserialization |
| ATK-025 | Low | 3.7 | Hash params, non-constant-time compare, OTP race | core/security.py:25,27,41; otp_service.py:67-84 | Crypto |
| ATK-026 | Low | 3.1 | Legacy React auth is client-side with hardcoded creds | frontend/src/pages/Login/LoginPage.tsx:70 | Legacy |
| ATK-027 | Low | 3.1 | Repo hygiene and destructive scripts | git history; seed_data.py; main.py:154-224 | Hygiene |
| ATK-028 | Low | 3.1 | Input validation gaps | audits.py:193; services/audit_report.py:60-80 | Validation |
| ATK-029 | Info | n/a | Dependencies not CVE-checked; some unpinned | requirements.txt; mobile/pubspec.yaml | Supply chain |
| ATK-030 | Info | n/a | Play policy checklist | AndroidManifest | Compliance |

## 3. Finding detail

### ATK-001 — Critical — `app/api/v1/routes/users.py:15-58`
CWE-306, CWE-862. All five user routes (create/list/get/update/delete) depend only on `get_db`. Any caller can list, edit (email, role, password) or delete any account, including admin. Confirmed in code.
**Fix:** `Depends(require_admin)` on every route, or remove the router (the mobile app does not use it). **Verify:** call each route with no token / non-admin token / admin token; expect 401 / 403 / success.

### ATK-002 — Critical — `routes/auth.py:48-59`; `schemas/user.py:24`; `crud/user.py create_user`
CWE-269, CWE-915. `/auth/register` is open and `role` (default "inspector") is stored as supplied; admin elsewhere is just `user.role == "admin"` (`crud/project.py:26,38`). Self-service admin accounts. Confirmed.
**Fix:** registration admin-only or invite-only; role set by server from an enum. **Verify:** unauthenticated register with role=admin returns 401/403 or the role is ignored.

### ATK-003 — Critical — `services/otp_service.py:32,51-53,59-64`; `routes/auth.py:68,84`; `mobile/lib/screens/login/login_screen.dart:492`
CWE-200, CWE-532, CWE-1188. `OTP_DEV_MODE` defaults on; the code is logged and returned as `dev_otp`. With the flag off, `send_via_smtp` raises `NotImplementedError` after the OTP row is committed, so request-otp errors and nobody can log in. In dev mode anyone who knows an account email can obtain a session for it; Play reviewers cannot log in either. Confirmed in code; the Railway env value needs runtime verification.
**Fix:** implement email delivery; production semantics by default; fail startup if mail unconfigured; remove `dev_otp` and code logging outside local dev; reviewer test-account mechanism. **Verify:** integration test with `OTP_DEV_MODE` unset asserting no `dev_otp` in response and no code in logs; startup check rejecting dev mode when a production flag is set.

### ATK-004 — Critical — `routes/upload.py:53-86`; `schemas/video.py:40,46-47`; `crud/video.py update_video`; `routes/videos.py:99-175`; `services/video.py:175-193`
CWE-22, CWE-73, CWE-862. The legacy route builds `filepath=f"uploads/videos/{video_in.file_name}"` unsanitised, and `UploadedVideoUpdate` lets clients set `filepath`/`processed_filepath`. Stored values are later passed to `os.path.join(base_dir, ...)` then `FileResponse`/`os.remove` without confining to the uploads root. Unauthenticated disclosure of any readable file and deletion of any deletable file; container runs as root (ATK-018). The normal upload path (`handle_video_upload`) is safe. Confirmed; special-file behaviour needs runtime verification.
**Fix:** remove legacy `/upload/video` POST/PUT/DELETE; remove path fields from client-writable schemas; resolve every stored path with `realpath` and require it inside uploads before read/delete; add auth + ownership. **Verify:** resolver unit tests with `../`, absolute paths, symlinks (expect rejection); PUT rejects/ignores path fields.

### ATK-005 — Critical — videos.py, upload.py, distress.py, gis.py, reports.py, maintenance.py, detection.py, live.py (all routes)
CWE-306, CWE-639, CWE-285. None use `get_current_user`; records addressed by sequential integer IDs with no ownership check. The mobile app sends its bearer token only on project/audit/asset/auth API calls, so the M1 login gate is only a client-side redirect (`mobile/lib/router/app_router.dart`). Anyone can read/create/alter/delete distress data, maintenance tasks, reports, upload videos and trigger processing. Confirmed.
**Fix:** router-level `dependencies=[Depends(get_current_user)]`, then per-resource authorization (project scoping); have the app send the token on all calls. **Verify:** iterate `app.routes` asserting each route (except an allow-list such as `/health`) returns 401 without a token.

### ATK-006 — High — `services/otp_service.py:17,35-36,67-84`; `routes/auth.py:71-104`
CWE-307, CWE-338. 6-digit codes from `random.choices` (not a CSPRNG); no attempt counter, lockout or rate limit; every request-otp adds another valid row; verify matches email+code across all unused rows. Online guessing account takeover. Confirmed.
**Fix:** `secrets.randbelow`; one active code per email, invalidated on new request; per-email and per-IP failure counters with lockout; store only a hash of the code. **Verify:** Nth wrong code locks the email; new request invalidates previous code; rate limiting returns 429.

### ATK-007 — High — `mobile/lib/data/http_overrides_io.dart:11-14`; `mobile/lib/main.dart:12`
CWE-295. `badCertificateCallback = (cert, host, port) => true` installed as the global `HttpOverrides`; every dart:io HTTP client and WebSocket accepts any certificate. A network-position attacker can read/alter all app traffic (OTP codes, tokens, uploads). Confirmed; effect on native players not established.
**Fix:** delete the override; valid certs for tunnel/test hosts, or limit any bypass to debug builds and named hosts. **Verify:** CI grep for `badCertificateCallback`; release build against a self-signed endpoint must fail to connect.

### ATK-008 — High — `routes/live.py:41-58,61-135,138-191`; `services/live/live_camera_service.py:158-209`
CWE-306, CWE-400, CWE-841. `/live/start`, `/stop`, `/phone-stream`, `/status`, `/stream`, `/ws` unauthenticated. In `phone_stream`, when a session is already running the handler closes and returns but the `finally` still calls `manager.stop()`, so a second connection terminates the first caller's session. Starting a session lazily loads two YOLOX models. Bytes from `receive_bytes()` go straight to `cv2.imdecode` with no size/dimension cap; detections persisted to `road_distresses` with snapshots. `/live/status` and `/live/ws` disclose checkpoint paths. Confirmed for missing auth and the `finally` bug; memory behaviour on a 1 GB host needs runtime verification.
**Fix:** authenticate WebSockets at accept time and HTTP routes via dependency; only `stop()` the session the connection owns; cap frame size/dimensions; one session per user; rate limits; drop filesystem paths from public status. **Verify:** unauthenticated WebSocket rejected; rejected second connection leaves first session running; oversized frame closes the socket.

### ATK-009 — High — `app/main.py:298-316`; `routes/audits.py:57-68`; `routes/assets.py:23-35`
CWE-552, CWE-639. `app.mount("/uploads", StaticFiles(...))` serves everything under `uploads/` with no auth. Project audio and documents are protected only by an unguessable UUID filename (no expiry/revocation). Video/detection locations are listed by unauthenticated `GET /videos/`. Confirmed.
**Fix:** serve files through authenticated routes that re-check project access, or short-lived signed URLs; keep the APK in a separate public location. **Verify:** `GET /uploads/<path>` without token returns 401/404; non-member gets 403 for another project's asset.

### ATK-010 — High — `routes/videos.py:23-36,51-82`; `detection.py:110-135`; `reports.py:70-107`; `auth.py:34-45`; `services/video.py:25-30`
CWE-770, CWE-400. Unauthenticated callers can repeatedly upload up to 500 MB, start AI pipeline runs, generate reports, walk the uploads tree (`/videos/storage/summary`) and trigger repeated PBKDF2 via `/auth/login`. The size limit is enforced while copying from an already-buffered upload. No rate limiting anywhere. Confirmed.
**Fix:** auth first; rate limits; per-user quotas; bounded job queue; early Content-Length cap at the proxy. **Verify:** staging load test confirming 429s and bounded disk/CPU.

### ATK-011 — High — `mobile/android/app/build.gradle.kts:19,30-32`; `AndroidManifest.xml:6,9`
CWE-319, CWE-530. Release uses `signingConfigs.getByName("debug")`; `applicationId = "com.example.mobile"`; `usesCleartextTraffic="true"`, no `networkSecurityConfig`, no `allowBackup` attribute (default enabled, so the token in preferences is backed up); label is "mobile". Play rejects a debug-signed or com.example package. Confirmed.
**Fix:** real application ID and upload keystore kept outside the repo (`key.properties`, `*.jks` already gitignored); cleartext false; network security config; `allowBackup="false"`; proper label. **Verify:** CI step `apkanalyzer manifest print` and `apksigner verify --print-certs` failing on debug certs or cleartext.

### ATK-012 — Medium — `otp_service.py:87-103`; `models/auth.py:30-40`; `mobile/lib/data/auth_provider.dart:46,105,124`
CWE-613, CWE-312. Tokens are random (`secrets.token_hex(32)`, good) but stored in clear in the DB, valid 30 days, never cleaned up, no server-side logout/revocation. App keeps the token in `shared_preferences` (plaintext on Android, localStorage on web); `logout()` only deletes the local copy. Confirmed.
**Fix:** store token hashes; `/auth/logout` deleting the row; shorter lifetime + refresh; purge expired rows; `flutter_secure_storage` on device. **Verify:** token fails after logout; DB holds no raw tokens.

### ATK-013 — Medium — `auth.py:53-58,80-84`; `users.py:25-32`
CWE-204. request-otp returns `dev_otp` only for existing accounts; with dev mode off, known emails error while unknown succeed; `/register` states the email exists; `GET /users/` lists everyone. Confirmed.
**Fix:** identical response for known/unknown emails; secure the user list. **Verify:** body, status and timing equivalent for known vs unknown emails.

### ATK-014 — Medium — `core/deps.py:30-33`; `crud/project.py:24-62`
CWE-285. `require_admin` is defined but never used; roles are free-text; any authenticated user can create projects and attach other users by email; owners are not added as members. Confirmed.
**Fix:** role enum; define admin-only actions and enforce with `require_admin`. **Verify:** role-by-route test matrix.

### ATK-015 — Medium — `app/main.py:33-39`; `nginx/nginx.conf`; `docker-compose.yml:31,43`; `DEPLOYMENT.md`
CWE-942, CWE-319, CWE-693. `allow_origins=["*"]` hardcoded (the `BACKEND_CORS_ORIGINS` setting is unused); nginx listens on port 80 only, no TLS/HSTS/CSP; Swagger `/docs` and openapi exposed. `allow_credentials=False` and bearer-header auth limit CSRF. Confirmed.
**Fix:** explicit origin list; terminate TLS; security headers; disable docs in production. **Verify:** `curl -I` for expected headers; testssl.sh.

### ATK-016 — Medium — `app/main.py:161`; `core/security.py:16-18`; `db/init_db.py:78`; `seed_data.py:46,52,58`; `DEPLOYMENT.md:96`
CWE-798. Startup seeds an admin with `hashed_password="hashed_placeholder_admin"`, and `verify_password` treats any stored value without `$` as a plaintext password. Documented default passwords (admin `Admi****`) appear in source and docs. `/auth/login` returns only a user object, not a token, so practical impact is limited today. Confirmed; the local dev DB has no plaintext-style hashes.
**Fix:** remove placeholder seeding and the plaintext fallback; require a bootstrap password from the environment. **Verify:** `verify_password` rejects values without a hash format; no production row lacks `$`.

### ATK-017 — Medium — `app/main.py:260-263`; `reports.py:72,107`; `videos.py:117-121,154-158`; `services/video.py:117`
CWE-209. Responses embed raw exceptions or server paths, e.g. `detail=f"Database connection is unhealthy: {str(e)}"`. Confirmed.
**Fix:** generic messages; log detail server-side. **Verify:** force each failure; response contains no paths or exception text.

### ATK-018 — Medium — `backend/Dockerfile:33`; `backend/.dockerignore`; `docker-compose.yml:9,28`
CWE-250, CWE-540, CWE-798. `.dockerignore` excludes `uploads/`, `models/`, `.venv` but not `.env`, `*.db` or `scripts/cloudflared.exe`; a local build would copy the dev database and the 54 MB binary into the image. Process runs as root, magnifying ATK-004. Compose uses a fixed DB password (`rdms****`); nginx has no TLS. Confirmed.
**Fix:** add exclusions; non-root user; DB credentials from secrets. **Verify:** `docker history` / `docker run --rm <image> ls`; `id` shows non-root.

### ATK-019 — Medium — `services/pdf_generator.py:163,354-374`
CWE-74, CWE-918 (potential). User-controlled strings go into `Paragraph` markup unescaped (e.g. `video.filename`). Image paths from `detection_image_path` (client-writable via `POST /distress/`) are joined to the base dir and passed to `Image(...)`. Needs runtime verification.
**Fix:** escape interpolated values (`xml.sax.saxutils.escape`); validate image paths against the uploads root. **Verify:** report with markup-like filename renders literally and causes no outbound request.

### ATK-020 — Medium — `services/ai/model_loader.py:135-170,251-254,295-298`; `.dockerignore`; `.gitattributes`
Insecure fallback. If the model file is missing or fails to load, the code substitutes `MockYOLO`, which emits random boxes with random confidences. Weights are Git LFS pointers and the Docker build excludes `models/`. A deployment without weights would report fabricated defects as real. Needs runtime verification for the deployed environment.
**Fix:** fail closed unless an explicit demo flag is set; surface model status in health checks. **Verify:** start without weights; processing endpoints return an error instead of detections.

### ATK-021 — Medium — `mobile/lib/screens/video_review/video_review_screen.dart:152,158`; `data/gis_api.dart:107`; `data/road_distress_api.dart:78`; `data/asset_api.dart:50`; `screens/dashboard/dashboard_shell.dart:13-66`; `data/live_detection_api.dart:25-68`
CWE-346. Several places do `url.startsWith('http') ? url : '$kApiBaseUrl/$url'`, so any absolute URL in API data is fetched directly; with writable records (ATK-004/005) clients can be pointed at third-party hosts. The server-config dialog accepts any URL (defaulting to http://), persists it, and the bearer token is then sent there. Default base is `http://localhost:8000` unless `API_BASE_URL` is compiled in. Confirmed.
**Fix:** only same-origin relative paths; restrict the override to debug builds or an allow-list; require HTTPS. **Verify:** unit-test the URL resolver with absolute URLs; assert rejection.

### ATK-022 — Medium — `scripts/run_stable_tunnel.py:16-17,50`; `scripts/serve_no_cache.py:267`; `scripts/cloudflared.exe`
CWE-494, CWE-295. The tunnel script runs `npx -y localtunnel` with `shell=True` (unpinned), falls back to SSH with `StrictHostKeyChecking=no`; the proxy script binds 0.0.0.0 and exposes the unauthenticated backend. A 54 MB `cloudflared.exe` sits in the working tree (gitignored, never committed, referenced by no script); sha256 `8635da433b6df8194746e88ed9d2589566c20e38bfc2a80e431a348b7c765841` (a hash, not a secret). Binary authenticity not verifiable offline.
**Fix:** pin tool versions; drop `StrictHostKeyChecking=no`; remove the unused binary; tunnel only authenticated builds. **Verify:** compare hash with the vendor checksum; dependency pinning check.

### ATK-023 — Low — `services/video.py:57-71`; `audit.py:25,44`; `asset.py:26,50,69`; `transcription_service.py:72`
CWE-434, CWE-20. Only the extension is checked; client `content_type` stored as sent. Files are later decoded by OpenCV, ffmpeg (via Whisper) and the video pipeline. Filenames sanitised and UUID-prefixed (good); no HTML/SVG allowed. `category`/`description` unvalidated; CSVs can contain spreadsheet formulas. Parser exposure Likely, needs runtime verification.
**Fix:** verify magic bytes; process media with resource limits/sandbox; keep dependencies patched; validate form fields. **Verify:** upload mismatched content; expect rejection.

### ATK-024 — Low — `services/live/yolox_engine.py:77,94`; `live_config.py:26-29`
CWE-502. `torch.load(..., weights_only=False)` and `get_exp(exp_file, None)` unpickle/execute whatever file is configured. Paths come from env vars or repo files (LFS), not users; requires write access to the deployment or repo. Confirmed.
**Fix:** `weights_only=True` where possible; verify checksums of weights at load; restrict who can set the env vars. **Verify:** startup check comparing weight hash to a pinned value.

### ATK-025 — Low — `core/security.py:25,27,41`; `otp_service.py:67-84`
CWE-916, CWE-208, CWE-362. PBKDF2-SHA256 at 100,000 iterations (below current guidance); comparisons use `==`; `verify_otp` does check-then-set without an atomic update so two concurrent requests could both succeed. Confirmed.
**Fix:** argon2/bcrypt or PBKDF2 at 600k+; `hmac.compare_digest`; atomic `UPDATE ... WHERE used=false`. **Verify:** parallel verification test; only one succeeds.

### ATK-026 — Low — `frontend/src/pages/Login/LoginPage.tsx:70`; `components/common/ProtectedRoute.tsx:4`
CWE-798, CWE-603. Legacy React login compares against literals in browser code and sets localStorage `isAuthenticated`. nginx serves the Flutter build, not this app. No impact on the deployed stack; a trap if ever deployed.
**Fix:** delete or archive the legacy app. **Verify:** no build step or deploy references `frontend/`.

### ATK-027 — Low — git history (commits `b154cda`, `4beaa1f`, `2bb9f0b`); `seed_data.py:35-41`; `reset_test_data.py`; `app/main.py:154-224`
CWE-200, CWE-1188. Old commits contain temporary tunnel hostnames (`funn****`, `tend****`, `.loca.lt`), private LAN IPs, committed detection JPEGs under `uploads/`, and personal email addresses in commit metadata. `seed_data.py` deletes all users/data with no environment guard. Startup re-seeds demo video 20 and forces user id 1 to be admin with a rewritten name. Confirmed.
**Fix:** environment guard on scripts; demo seeding behind a flag; consider scrubbing history if the repo is public. **Verify:** startup on an empty DB with the production flag creates no demo rows.

### ATK-028 — Low — `audits.py:193`; `services/audit_report.py:60-80`; `schemas/audit.py:26-31`; `schemas/project.py:93`
CWE-20, CWE-1284. `interval_km` unbounded (loop capped at 500 buckets); severity/category free text; `chainage_km` can be NaN/inf; `member_emails` has no length limit. Confirmed.
**Fix:** constrained types (`gt=0`, enums, `allow_inf_nan=False`, max list length). **Verify:** boundary-value tests expect 422.

### ATK-029 — Info — `requirements.txt`; `mobile/pubspec.yaml`
CWE-1104. Vulnerability databases could not be queried offline. Installed versions match `requirements.txt`. Flutter has a lock file. Needs a scanner run.
**Fix:** pin everything, scan in CI. **Verify:** `pip-audit`, `flutter pub outdated`, OSV/Dependabot.

### ATK-030 — Info — `AndroidManifest.xml`; app functionality
Compliance checklist: Data Safety form (email, audio, camera frames, uploaded media); privacy policy URL; in-app account deletion if accounts can be created; justification for camera/microphone/storage permissions; a stable reviewer login (see ATK-003). The backend also serves an APK at `/download-apk`, which should not be part of the store build's update path.

## 5. Secrets inventory (redacted to 4 characters + `****`)

| Item | Where | In git history? | Rotate? |
|---|---|---|---|
| `backend/.env` (`DATABASE_URL=sqli****` local SQLite path, `BACKEND_CORS_ORIGINS=*****`) | ignored by `.gitignore:51` and `backend/.gitignore:6` | No | No; but `.dockerignore` does not exclude it (ATK-018) |
| Default admin password `Admi****` | `init_db.py:78`; `seed_data.py:46`; `test_user_crud.py:120`; `DEPLOYMENT.md:96` | Yes | Yes — treat as public |
| Seed user passwords `Insp****`, `Main****` | `seed_data.py:52,58`; `test_user_crud.py` | Yes | Yes, if those accounts exist anywhere |
| Admin placeholder hash `hash****` | `app/main.py:161` | Yes | Yes — replace on any deployed DB |
| Legacy mock login `admin@akcm.com` / `Admi****` | `frontend/.../LoginPage.tsx:70`; `mobile/README.md:29-30` | Yes | No (unused), retire it |
| Compose Postgres password `rdms****` (user `rdms_user`) | `docker-compose.yml:9,28` | Yes | Yes, if reused |
| Settings default DB password `post****` | `app/core/config.py:24` | Yes | Yes, if any real DB uses it |
| Temporary tunnel hostnames `funn****`, `tend****` (.loca.lt) | commits `b154cda`, `4beaa1f` | Yes | No (ephemeral) |
| Local SQLite `road_distress.db` (2 users, 17 plaintext session tokens, 650 distress rows) | `backend/road_distress.db` | No (`*.db` ignored) | Invalidate tokens before the file goes anywhere |
| `scripts/cloudflared.exe` (54 MB) | `backend/scripts/` | No | Not a secret; verify vs vendor hash or delete |
| Signing keystore, key.properties, google-services.json, API keys, SMTP creds, JWT secret | Not found in repo | No | N/A (release currently uses the developer's debug key, not in repo) |

Regex scans over tracked files and full history found no cloud keys, GitHub tokens, private-key blocks, or DB URLs with embedded credentials. Model weights in git are LFS pointers; no blob over 2 MB exists in history. A stash commit and all remote refs were included.

## 6. Checked and found safe
- SQL injection: all `text()` calls are static strings; everything else uses the ORM with bound parameters.
- Upload filename handling on the normal upload paths: basename + allow-list + UUID prefix.
- StaticFiles: Starlette traversal protection applies; no directory listing; symlinks not followed.
- Command injection: no subprocess/shell with user data in the app (only dev scripts, see ATK-022).
- Session token entropy (`secrets.token_hex(32)`, unique index, expiry enforced on lookup).
- OTP expiry (10 min) and used-flag enforced (race noted in ATK-025).
- Projects / Audits / Assets authorization: every route calls `_require_project_access` / `_require_audit_access`; audio delete checks `clip.audit_id == audit_id`; asset delete checks project access. No IDOR found (subject to ATK-002).
- No outbound HTTP client code in the app (SSRF only via ATK-019).
- No pickle/yaml.load/XML parsing/archive extraction of uploads in app code (see ATK-024).
- `EMAIL_REGEX` backtracking bounded by `max_length=255`.
- CORS credentials off + bearer-header auth: wildcard CORS does not enable cookie CSRF.
- Report download routes read paths from server-generated rows.
- No arbitrary-file-write primitive found in server code.
- Stored XSS through uploads not viable as built (non-HTML types, extension-derived content type, Flutter canvas, non-cookie auth); `nosniff` + CSP still recommended.
- Android: only launcher activity exported; not debuggable; no custom deep links; no hardcoded API keys in Dart. Permissions: INTERNET, CAMERA, RECORD_AUDIO, READ/WRITE_EXTERNAL_STORAGE (write capped at API 28), ACCESS_NETWORK_STATE, WAKE_LOCK.
- iOS Info.plist has no ATS exemption.
- Git: `.env`, `*.db`, APKs, mp4, keystores, google-services never committed.

## 7. Rules-of-engagement compliance (as stated by the attacker)
Wrote/edited/moved/deleted nothing; only read-only git commands; no network calls; installed nothing; started no servers; ran no exploit. Local read-only actions beyond reading source: aggregate counts from the untracked local dev DB (opened read-only, no emails/tokens/hashes displayed); sha256 and PE info of `cloudflared.exe`; reading `.venv` dist-info names; one repo-wide grep unintentionally traversed `backend/.venv` (nothing modified). No secret was used.
Not checked: the Railway runtime (no `railway.json`/Procfile in repo; env vars unknown); live CVE status; TLS/headers of any deployed host; the real debug keystore; APK contents; runtime behaviour of OpenCV/ffmpeg/Whisper on crafted media and ReportLab on injected markup; whether special files can be returned by `FileResponse`.
