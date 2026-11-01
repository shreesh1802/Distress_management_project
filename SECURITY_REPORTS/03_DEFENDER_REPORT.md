# 03 — Defender Report

**Scope:** hardening of the owner's own repository (FastAPI backend, Flutter app, Docker/nginx config) against the verified findings in `01_ATTACKER_REPORT.md` and `02_SUPERVISOR_REPORT.md` (the supervisor's handoff and corrections were treated as authoritative).
**State of the tree:** everything is an uncommitted working-tree change (59 modified files incl. `docker-compose.yml` and the login screen, 20 new paths, see section 10). Nothing was staged, committed, stashed or pushed; no servers were started or stopped; no network calls were made except `pip install pytest httpx` into the backend venv (section 9).
**Not touched:** `backend/.env`, every `*.db`, `backend/uploads/`, `scripts/cloudflared.exe`, the legacy React app, `.github/`, `01_*`/`02_*` reports, signing config and `applicationId`.

---

## 1. Summary

Most critical and high findings that can be fixed in the repository are fixed and covered by an automated test (Round 1 overstated this: see the corrections to ATK-005/013/014 and section 11, Round 2); the remainder needs a decision or an account only the owner has.

* **Authentication everywhere.** Every legacy route (videos, upload, distress, gis, reports, maintenance, detection, live) now requires a bearer token, enforced once in `app/main.py` via router-level dependencies. Only `/health`, `/api/v1/health`, the login flow (`login`, `request-otp`, `verify-otp`), `register` (in Round 1 open to everyone; since Round 2 admin-only unless `ALLOW_SELF_REGISTRATION` is on, which is the development default), and the APK sideload links are public. The report download/preview GETs accept a bearer token **or** a 5-minute HMAC-signed link. The two live WebSockets use a first-message token (never a URL token). The Flutter app was changed in the same patch so it sends the token on every call.
* **Account and session hardening.** `/auth/register` can no longer create admins (role is server-assigned, a client `role` is ignored); roles are an allow-list; the users router is admin-only for writes and returns a reduced directory to normal users; sessions are stored as SHA-256 hashes, last 7 days, and can be revoked with the new `POST /auth/logout`.
* **OTP login is production-capable.** CSPRNG codes, one active code per e-mail, constant-time compare, atomic single-use, per-e-mail and per-IP lockouts, uniform responses, normalised e-mails, no code in logs, real stdlib SMTP sender. `APP_ENV=production` makes the process refuse to start unless SMTP, CORS and the signing secret are configured.
* **File-path attacks closed.** One helper (`app/core/safe_paths.py`) confines every database-stored path to `uploads/` or `reports/` before any read, delete, serve or PDF embed; client-writable path fields were removed from the HTTP schemas; the legacy upload route sanitises file names.
* **Mobile.** TLS bypass only in debug builds; `allowBackup=false`; cleartext only through a debug-only manifest overlay; proper app label.
* **Safeguards so it cannot silently regress:** 322 pytest tests after Round 2 (241 after Round 1; in-process, temporary SQLite), an offline `scripts/security_check.py`, `SECURITY.md`, `requirements-dev.txt`. A proposed CI workflow is in section 8 (not created).

**Verification results (all run against a temporary SQLite database; the real DB was never opened):**

| Check | Result |
|---|---|
| `python -c "import app.main"` | OK (development defaults; production without config exits non-zero with a clear message, shown in section 7) |
| `pytest tests/security` | **322 passed** after Round 2 (241 after Round 1; about 50 s) |
| End-to-end dev flow (`request-otp` → `verify-otp` → `/me` → create user → project → audit → checklist item → chainage report → asset upload → logout) | all expected status codes (200/201/204/401), run in-process |
| Mutation spot-check (re-introduced: unauthenticated videos router, unconfined stream path, plaintext password fallback, unconditional `manager.stop()`) | the suite failed on each (7 tests failed), then the code was restored |
| `scripts/security_check.py` | passes; lists 5 knowingly deferred items; `--strict` fails on them as designed |
| `flutter analyze --no-fatal-infos` | 0 errors; 17 issues, all pre-existing (the one new warning I introduced, an unused import, was removed) |
| `flutter test` | 40 pass, 3 fail. The 3 failures are in files I did not touch: `widget_test.dart` still looks for the old login text "Administrator Access"; two `DetectionsSidebar` tests hit a pre-existing RenderFlex overflow. I could not run the pre-change baseline (git stash/checkout were not allowed), so "pre-existing" is based on those files being untouched |
| Real YOLOX checkpoints loaded with `weights_only=True` (new narrow allow-list) and one inference run, with `ALLOW_MOCK_MODEL=false` | OK, `/health` model status "real" |

**Not tested (be aware):** the Docker build, the Android build / manifest merge, the Flutter app on a device or against a running server (the backend side of every client behaviour is tested via TestClient, the Dart side is only type-checked), STARTTLS/TLS against a real SMTP server (the sender is tested against an in-process fake SMTP server without TLS and with AUTH), the edited `run_stable_tunnel.py` (needs Node/network), and the proposed CI YAML.

---

## 2. Finding-by-finding status

Status values: FIXED / PARTIALLY FIXED / DEFERRED-OWNER-DECISION / DEFERRED-DESIGN / WONT-FIX. "Tests" names the file in `backend/tests/security/` that proves it.

| ID | Status | What changed (files) and how | Tests |
|---|---|---|---|
| **ATK-001** Unauthenticated user API | FIXED | `routes/users.py`: POST/PUT/DELETE use `require_admin`; GET list/by-id use `get_current_user` and return the reduced `UserPublic` (id, full_name, role; e-mail only for admins or self). Limit capped at 200. Dart `AppUser` tolerates a missing e-mail (`displayName`), so the maintenance and reports screens keep working. | `test_accounts_roles.py`, `test_route_auth.py` |
| **ATK-002** Register accepts a role | FIXED | `schemas/user.py` (`RegisterRequest` has no role field), `routes/auth.py` (server sets `SELF_REGISTER_ROLE`), `core/roles.py` (constants, `RoleName` literal), `crud/user.py`. Duplicate e-mail returns a generic 400. Per-IP rate limit. | `test_accounts_roles.py` |
| **ATK-003** OTP returned/logged, dev default, no prod mode | FIXED (code) / DEFERRED-OWNER-DECISION (provider, Railway env) | `core/config.py` (`APP_ENV`), `core/startup_checks.py` (fails closed), `services/otp_service.py`, `services/email_sender.py` (stdlib smtplib, env-configured, provider-neutral), `routes/auth.py`. Production: `dev_otp` is always null, code never logged, `OTP_DEV_MODE=true` aborts startup. Development: unchanged for the owner's demo, except the code is no longer written to the console log. | `test_otp_login.py`, `test_production_config.py`, `test_email_sender.py` |
| **ATK-004** Client-controlled file paths | FIXED | New `core/safe_paths.py`; used by `routes/videos.py`, `services/video.py`, `routes/reports.py`, `services/audit.py`, `services/asset.py`, `services/transcription_service.py`, `services/pdf_generator.py`, `services/ai/frame_extractor.py`, `services/pipeline/pipeline_manager.py`. `schemas/video.py` splits `UploadedVideoClientUpdate` (status only, `extra=forbid`) from the internal `UploadedVideoUpdate` the pipeline uses; `schemas/distress.py` splits `RoadDistressClientCreate` (no `detection_image_path`) from the internal create schema used by the tracker. Legacy `POST /upload/video` sanitises `file_name` and uses the caller as uploader. Demo seed paths (`uploads/crops/...`, `uploads/processed/...`) still resolve. | `test_safe_paths.py` (50 tests: `../`, absolute, drive letters, UNC, backslashes, NUL, symlink escape, prefix-sibling) |
| **ATK-005** Legacy routes unauthenticated | PARTIALLY FIXED (Round 1 said FIXED: overstated). Anonymous callers are now rejected on every route, but any *signed-in* user still has full access to all legacy data and actions (no ownership or role checks), and in Round 1 anyone could become signed-in by self-registering; since Round 2 registration is admin-only outside development. | `app/main.py` router-level `dependencies=[Depends(get_current_user)]` for distress, gis, reports, maintenance, videos, upload, detection, live (HTTP). The Flutter token is attached centrally in `data/custom_http_client.dart` (every API class already used `CustomHttpClient`; it adds `Authorization` to requests to the configured backend only) and the 401 handler signs the user out. No per-user/per-project scoping on these routes yet (see residual risks). | `test_route_auth.py` (every route, anonymous and invalid token) |
| **ATK-006** OTP guessing | FIXED | `otp_service.py`: `secrets.randbelow`, 5 wrong codes lock the e-mail for 15 min (the right code is refused too, and a new request does not lift the lock), 100 failures/15 min lock an IP, 5 codes per 10 min per e-mail, 60 requests per 10 min per IP. In-process counters (per instance). Code is **not hashed** (the 6-digit column is `varchar(6)` and a schema change was out of scope; a hash of a 10^6 space adds little). | `test_otp_login.py` |
| **ATK-007** TLS validation disabled | FIXED (not run on a device) | `data/http_overrides_io.dart`: override installed only when `kDebugMode`; callback returns `kDebugMode`. Web stub unchanged. | `security_check.py` rule `dart-bad-cert` |
| **ATK-008** Live routes unauthenticated, stop bug | FIXED for HTTP and WebSockets | `routes/live.py`: HTTP routes behind the router dependency; `/live/ws` and `/live/phone-stream` require `{"type":"auth","token":...}` as the first text frame within 5 s (`core/ws_auth.py`), otherwise close 1008; only the connection that owns the session calls `stop()`; frames capped at 4 MB, JPEG/PNG header dimensions checked before decoding (max 4096 px), garbage skipped; `services/live/live_camera_service.py` no longer publishes checkpoint/exp paths; start errors are generic. Dart `LiveDetectionApi` sends the auth frame; `MjpegView` uses the authenticated client. `nginx.conf` now forwards the `phone-stream` upgrade too. **Not done:** one session per user, per-user rate limits. | `test_live.py` |
| **ATK-009** Public `/uploads` | DEFERRED-DESIGN | Unchanged (still a public static mount). Videos, detection images and report-independent files remain readable by path; audio/assets only by unguessable UUID names. Suggested design: remove the mount, serve media through authenticated routes or signed URLs (same HMAC mechanism as report links), and have the app use `Image.network(headers:)` / `VideoPlayerController(httpHeaders:)` on mobile plus signed URLs on web. | `PUBLIC_MOUNTS` is asserted in `test_route_auth.py`, so a new mount cannot appear unnoticed |
| **ATK-010** Resource exhaustion | PARTIALLY FIXED | Authentication first; rate limits on login (30/min/IP), register (20/h/IP), request-otp, verify-otp; pagination caps (<=1000, users <=200); live frame limits. Not done: per-user upload quotas, bounded job queue, proxy body-size cap review. | `test_accounts_roles.py`, `test_otp_login.py` |
| **ATK-011** Android release config | PARTIALLY FIXED / DEFERRED-OWNER-DECISION | `AndroidManifest.xml`: `allowBackup=false`, `usesCleartextTraffic=false`, label "Road Inspection"; `src/debug/AndroidManifest.xml` re-enables cleartext for debug builds only (`tools:replace`). `key.properties`, `*.jks`, `*.keystore` confirmed git-ignored and not tracked. **Owner:** final `applicationId`, release keystore + signing config (left untouched; `security_check.py` lists these as deferred). No `networkSecurityConfig` added. Merge was not built. | `security_check.py` |
| **ATK-012** Session lifecycle | FIXED (server) / DEFERRED-DESIGN (secure storage) | `otp_service.py` (SHA-256 hash stored in the existing `token` column, 7-day TTL, expired rows purged on login, `revoke_token`), `POST /auth/logout`, Dart `logout()` calls it best-effort before clearing state. `flutter_secure_storage` (new native plugin) deferred: token still in `shared_preferences`. | `test_sessions.py` |
| **ATK-013** User enumeration | PARTIALLY FIXED (Round 1 said FIXED: overstated) | Uniform request-otp/verify-otp responses (SMTP send runs after the response), generic register error, `/users` requires login. In development `dev_otp` is still present only for known accounts (kept deliberately for the demo, so development is not enumeration-safe). Any signed-in user can still list all user names via `/users/`, and the project-member form reveals which e-mails have accounts. Round 2: a per-e-mail OTP lock now looks like an ordinary wrong code and unknown addresses create no per-e-mail state. | `test_otp_login.py`, `test_accounts_roles.py` |
| **ATK-014** Thin authorization model | PARTIALLY FIXED (stays partial: authorization is still all-or-nothing for the legacy routes; any signed-in user can delete reports, videos, tasks and stop live sessions) | Role constants/allow-list, `require_admin` now used, role changes admin-only, owners see their own projects. Per-resource scoping on the legacy M1 routes is not implemented. | `test_accounts_roles.py`, `test_idor_uploads.py` |
| **ATK-015** CORS/headers/docs | FIXED (app) / owner (TLS) | CORS from `BACKEND_CORS_ORIGINS` (default `*` only in development, `*` rejected in production); `core/security_headers.py` (nosniff, X-Frame-Options DENY, Referrer-Policy, `Cache-Control: no-store` on `/api/`); `/docs`, `/redoc`, OpenAPI disabled in production. HSTS/CSP given as nginx guidance in `SECURITY.md` (not enabled: no TLS terminator in the repo). | `test_production_config.py`, `test_downloads_headers_misc.py` |
| **ATK-016** Default creds / plaintext fallback | FIXED | `core/security.py` rejects anything that is not a well-formed hash (plaintext, `"hashed_placeholder_admin"`, `"!"`); hashes are now `pbkdf2_sha256$600000$...` (legacy `salt$hash` still verifies); `db/bootstrap.py` stores the unusable marker `"!"` and rewrites the old placeholder at startup; `init_db.py`, `seed_data.py` no longer create known passwords; `DEPLOYMENT.md` no longer documents a default password; `POSTGRES_PASSWORD` has no default. | `test_accounts_roles.py`, `test_production_config.py` |
| **ATK-017** Verbose errors | FIXED | Generic messages in `main.py` (/health), `routes/reports.py`, `routes/videos.py`, `services/video.py`, `audio/asset` services, `routes/live.py`, pipeline failure stage; 422 handler never echoes input (this also fixed a crash: a JSON `NaN` made FastAPI's default handler return 500). Details are logged server-side. | `test_downloads_headers_misc.py`, `test_live.py` |
| **ATK-018** Docker | PARTIALLY FIXED (unbuilt) | `Dockerfile`: unprivileged `app` user (uid 10001), `docker-entrypoint.sh` chowns the upload/report/cache volumes then drops privileges with `gosu`; `.dockerignore` excludes `.env*`, `*.db`, `*.exe`, `.cache/`, `__pycache__`, tests, keystores. Compose database password literal deferred (listed in `security_check.py`). | `security_check.py` rule `docker-root` |
| **ATK-019** ReportLab markup injection | FIXED | `services/pdf_generator.py`: every user-controlled string goes through `xml.sax.saxutils.escape`; images are opened only if the path resolves inside `uploads/`; at most 40 frames embedded. **Behaviour note:** the old code joined image paths to the wrong base directory, so frames were never actually embedded; they now are. | `test_downloads_headers_misc.py` |
| **ATK-020** MockYOLO fabricates detections | FIXED | `services/ai/model_loader.py`: mock only if `ALLOW_MOCK_MODEL` (default on in development, off in production), otherwise `ModelUnavailableError` and the video is marked failed; `services/ai/model_status.py` + `/health` report weights present / runtime / mock allowed / loaded state without loading a model. | `test_production_config.py` |
| **ATK-021** App trusts server URLs, URL override | DEFERRED-DESIGN | Out of the requested scope. Mitigated: the bearer token is only attached to requests for the configured backend origin. Suggestion: resolve data URLs against the configured base only, and restrict the server-URL dialog to debug builds or an allow-list. | — |
| **ATK-022** Dev tooling supply chain | PARTIALLY FIXED / DEFERRED-OWNER-DECISION | `backend/scripts/run_stable_tunnel.py`: no `shell=True`, pinned `localtunnel@2.0.2`, `StrictHostKeyChecking=accept-new` (**not run**). `cloudflared.exe` untouched: owner should verify its hash or delete it (it is git-ignored and now excluded from Docker images). | `security_check.py` |
| **ATK-023** Upload validation | FIXED | `core/upload_checks.py`: content type derived from the extension; magic bytes verified only for PDF, PNG, JPEG, docx/xlsx (`PK`), WAV; permissive for doc/xls/csv/txt/mp3/m4a/aac/ogg/webm; asset category is an enum, description max 2000. Videos are not sniffed (mp4/mov signatures are not reliable enough). | `test_idor_uploads.py` |
| **ATK-024** Unsafe deserialisation | FIXED (checkpoints) / PARTIAL (exp files) | `services/live/yolox_engine.py`: `torch.load(weights_only=True)` with a narrow numpy allow-list (verified against both shipped checkpoints); `weights_only=False` reachable only with `YOLOX_ALLOW_UNSAFE_CHECKPOINT=true`. `get_exp(exp_file)` still executes a configured exp file (env/repo controlled, not user controlled). | real checkpoint load verified manually; `security_check.py` rule |
| **ATK-025** Crypto details | FIXED | 600k PBKDF2 iterations for new hashes, `hmac.compare_digest` for passwords, OTP and signed links, atomic `UPDATE ... WHERE used = false`. Legacy hashes are not auto-upgraded on login. | `test_otp_login.py` (8-way concurrency: exactly one success), `test_accounts_roles.py` |
| **ATK-026** Legacy React login | DEFERRED-OWNER-DECISION | Untouched; deleting/archiving it is the owner's call. Listed in `security_check.py` deferrals. | — |
| **ATK-027** Repo hygiene, destructive scripts, startup seeding | FIXED (code) / DEFERRED-OWNER-DECISION (history) | Demo video 20 + 8 detections + the user-1 rename only run when `SEED_DEMO_DATA` is on (default off in production); `core/env_guard.py` makes `seed_data.py`, `reset_test_data.py`, `add_demo_detections.py`, `register_demo_video.py` refuse to run in production or against a non-SQLite database unless `ALLOW_DESTRUCTIVE_SCRIPTS=yes-i-know-this-wipes-data`. Git history was not rewritten. | `test_production_config.py` |
| **ATK-028** Input validation | FIXED | Literal enums for audit category/severity, distress severity, model source; `interval_km` in (0,100]; `chainage_km` finite, 0..100000; lat/lon ranges; `member_emails` <= 100 entries of <= 255 chars; string length caps. | `test_idor_uploads.py`, `test_downloads_headers_misc.py` |
| **ATK-029** Dependencies | PARTIALLY FIXED | `requirements-dev.txt` adds pytest, httpx, pip-audit; `pip-audit` was **not run** (needs network). `pycocotools>=2.0.2` is still unpinned (installed 2.0.11): pin it after a build. | — |
| **ATK-030** Play checklist | DEFERRED-OWNER-DECISION | Checklist written in `SECURITY.md`. | — |
| **SUP-001** Project membership | PARTIALLY FIXED | Owners now see their own projects (`get_visible_projects`); member list is deduplicated (a duplicate in one request used to raise a database error). Any signed-in user can still attach registered accounts by e-mail and the response lists matched members (enumeration oracle among signed-in users): accepted, by design of the project form. | `test_idor_uploads.py` |
| **SUP-002** E-mail normalisation | FIXED | `normalize_email` used in lookup (case-insensitive), registration, admin create/update, project members, OTP keys. | `test_otp_login.py`, `test_idor_uploads.py` |
| **SUP-003** Pagination caps | FIXED | `core/pagination.py`; the app's largest requests (1000 / users 200) still work. | `test_accounts_roles.py` |
| **SUP-004** Predictable admin + dev OTP | FIXED in production / accepted in development | In production no demo admin is created and `dev_otp` does not exist; a startup warning is logged if the old default account is still in the database. Development keeps the demo account by design. | `test_production_config.py` |
| **SUP-005** Runtime model downloads | DEFERRED-DESIGN | Not changed. Pin and pre-bake the Whisper model (`WHISPER_MODEL`, copy the weights into the image or a volume) so the server does not download at first use; keep ffmpeg in the image instead of copying it into `.cache/` at runtime. | — |

---

## 3. New safeguards

| Safeguard | Where | Run it |
|---|---|---|
| Security test-suite (241 tests, in-process, temporary SQLite, storage roots redirected to a temp dir) | `backend/tests/security/` (`pytest.ini` limits collection to `tests/`) | `cd Road-Distress-Management-System/backend && python -m pytest tests/security` |
| Route-auth matrix: iterates every route (including `include_router` ones and the OpenAPI document), asserts 401 anonymously and with a bad token, and asserts the public allow-list and the static-mount list exactly | `test_route_auth.py` | same |
| Role matrix, register cannot create admins, reduced user directory, pagination caps | `test_accounts_roles.py` | same |
| Path-confinement unit and API tests | `test_safe_paths.py` | same |
| OTP, lockout, single use, invalidation, uniform responses, no code in logs, production/dev behaviour, concurrency | `test_otp_login.py`, `test_email_sender.py` | same |
| Sessions: logout, hashing, expiry, purge, TTL | `test_sessions.py` | same |
| Project/audit/asset/audio IDOR and upload validation (rejected extension, content mismatch, oversize) | `test_idor_uploads.py` | same |
| Live WebSocket auth, session ownership, frame limits, no paths in status | `test_live.py` | same |
| Production fail-closed start-up (real subprocesses), bootstrap/seeding gates, mock-model gate, script guards | `test_production_config.py` | same |
| Signed download links, headers, generic errors, PDF/Excel injection, schema constraints | `test_downloads_headers_misc.py` | same |
| Static check (stdlib only, offline, exit code 1 on findings, inline `# security-check: ignore <rule> -- <reason>`, justified allow-list) | `scripts/security_check.py` | `python scripts/security_check.py` (`--strict` also fails on deferred items) |
| Documentation of the above, production variables, TLS/CSP guidance, Play checklist | `SECURITY.md` | — |
| Dev dependencies | `backend/requirements-dev.txt` | `pip install -r requirements-dev.txt` |

---

## 4. Owner action list

**Decisions only the owner can make or accounts only the owner has (nothing below was done by me):**

1. **Railway environment (do this together, in one deploy).** To turn the production posture on set: `APP_ENV=production`, `DATABASE_URL` (as today), `SMTP_HOST`, `SMTP_FROM`, `SMTP_USER`/`SMTP_PASSWORD` (+ `SMTP_PORT`, `SMTP_STARTTLS` if your provider needs them), `DOWNLOAD_SIGNING_SECRET` (>= 32 random characters), `BOOTSTRAP_ADMIN_EMAIL` (a mailbox you control), `TRUSTED_PROXY_COUNT=1`, and either leave `BACKEND_CORS_ORIGINS` unset (native apps need none) or list exact HTTPS origins. **Remove** any `BACKEND_CORS_ORIGINS=*` and any `OTP_DEV_MODE=true`: the server will refuse to start with them in production. Do not switch `APP_ENV` before SMTP works, otherwise nobody can log in. Until you do, the deployment keeps the development defaults and the dev OTP shortcut (including for `admin@roaddistress.org`) stays reachable on the internet.
2. **Choose an e-mail provider** (any SMTP service) and create credentials; send yourself a test login before the store submission.
3. **AI weights in production.** The Docker image excludes `models/` and the weights are Git LFS pointers. With `APP_ENV=production` the mock detector is off, so video processing will fail ("detection model not available") unless the weights are mounted/baked in. Provide them (preferred), or set `ALLOW_MOCK_MODEL=true` knowing results are random.
4. **Existing production database.** All existing sessions stop working (tokens are now stored hashed): users log in again. If the database was seeded by the old code or `init_db`, user 1 `admin@roaddistress.org` still exists and some rows may carry the well-known password hash. Suggested statements (review before running): `UPDATE users SET hashed_password='!' WHERE hashed_password='hashed_placeholder_admin' OR email='admin@roaddistress.org';` (the placeholder is also rewritten automatically at startup) and `UPDATE users SET email='<your real admin e-mail>' WHERE id=1;` (or let `BOOTSTRAP_ADMIN_EMAIL` create a new admin and delete the old account through `DELETE /users/1`).
5. **Rotate/retire credentials listed in the attacker's secrets inventory** if they exist anywhere real: the documented default admin password, the seed-user passwords, the Compose Postgres password, any database that used the old `postgres` default. I did not rotate or print any real credential.
6. **Play release:** final `applicationId` (and `namespace`/`MainActivity` package), upload keystore + `key.properties` (outside git) + a release `signingConfig` in `mobile/android/app/build.gradle.kts`; build with `--dart-define=API_BASE_URL=https://...`. I left the debug-signed release config and the `com.example.mobile` id in place on purpose; `security_check.py` reports them as deferred.
7. **Git history:** decide whether to scrub old commits (tunnel hostnames, committed JPEGs, personal e-mails in metadata). Not done.
8. **Delete or archive** the legacy React app (`frontend/`) and `scripts/cloudflared.exe` (verify its hash against the vendor first if you keep it).
9. **TLS:** terminate HTTPS in front of the backend, then add the HSTS/CSP block from `SECURITY.md` to nginx.
10. **Approve (or reject) the CI workflow** in section 8.
11. **Before publishing the store build:** remove `/download-apk`, `/app-release.apk` and `uploads/RoadDistress.apk` from the production server; create a Play reviewer account on a mailbox you control; publish a privacy policy; complete the Data Safety form and account-deletion requirements (details in `SECURITY.md`).
12. **Deferred designs you may want to schedule:** `flutter_secure_storage` for the token; signed-URL serving to replace the public `/uploads` mount; per-user/per-project scoping for the legacy M1 routes; pinning the Whisper model and `pycocotools`.

**Also note (not an action I took):** the local `backend/.env` contains `BACKEND_CORS_ORIGINS=*`. That is fine for development but would make a `APP_ENV=production` start fail on that machine; I did not modify the file.

---

## 5. Behaviour changes the owner will notice

* **Login is required for everything except the login screen.** Old app builds (and the Flutter web dev server on :5173 that is currently running the old code) will get 401 on videos, reports, analytics, maintenance, live detection and the GIS map until rebuilt/restarted with this change. A 401 now sends the user back to the login screen.
* **All existing sessions are invalidated** (hashed token storage), and sessions last **7 days** instead of 30. The app logs out on the server when you tap logout.
* **OTP:** development still shows the code on the login screen, but the code is no longer printed in the backend console. Requesting more than 5 codes in 10 minutes for one address, or entering 5 wrong codes (15-minute lock, even for the right code), is throttled.
* **Production mode** (`APP_ENV=production`): no code in the response, login codes arrive by e-mail, `/docs` is gone, no demo data, no mock detector, strict CORS, startup refuses to run when misconfigured.
* **Reports:** PDF/Excel download and preview open through a short-lived signed link requested from the server. The old fallback that downloaded hard-coded report 28/29 when generation failed was removed; a snackbar is shown instead. Generated PDFs now actually embed annotated detection frames (up to 40), which they never did before because of a path bug.
* **Users screen data:** `/users` returns id, name and role (e-mail only for admins and your own record). The maintenance screens show the name, or "User #id" when a user has no name.
* **API strictness:** `PUT /upload/video/{id}` accepts only `processing_status`; `POST /distress/` ignores/forbids server file references and validates severity/coordinates; password minimum is 8 characters (register and admin create); invalid input returns 422 without echoing the input; list endpoints reject `limit` above 1000 (users 200).
* **Videos:** the uploader is always the signed-in user; deleting a video only removes files located under `uploads/`.
* **Android:** release/profile builds can talk HTTPS only and validate certificates; debug builds keep plain HTTP and the relaxed certificate check; Android backups are off; the launcher label is "Road Inspection".
* **Docker:** the container starts as root only to fix volume ownership, then runs as user `app`. Local files such as `.env`, `*.db`, `.cache/` and `*.exe` are no longer copied into images. `docker-compose` is unchanged (still development defaults and its demo password).
* **nginx:** `/api/v1/live/phone-stream` is now forwarded with the WebSocket upgrade, like `/live/ws`.
* **Scripts:** `seed_data.py` and friends refuse to run in production or on non-SQLite databases without an explicit override; `seed_data.py` creates accounts without passwords (use Email + OTP). `reset_test_data.py` targets PostgreSQL syntax, so on a local PostgreSQL it now needs the override too.
* **Stale legacy scripts:** the root-level `backend/test_*.py` scripts (e.g. `test_user_crud.py`, `test_video_upload.py`) drive a live server without a token and will now receive 401; they were not updated and are not part of `pytest` (`pytest.ini` collects only `tests/`).
* **Settings:** `POSTGRES_PASSWORD` no longer defaults to `postgres`. Because settings are read through pydantic, an `OTP_DEV_MODE` value in `.env` is now honoured (previously only real environment variables were).

---

## 6. Residual risks

* `/uploads` is public (ATK-009). Anyone who learns a file path can fetch videos and detection images; audio/assets are protected only by random file names.
* After login, any signed-in user can read and modify all legacy M1 data (videos, distress records, reports, maintenance tasks, live control). Role and project scoping for those routes was not implemented.
* `/auth/register` is open only while `ALLOW_SELF_REGISTRATION` is on (default: development only). With it on, anyone who owns a mailbox can obtain a login that works on every legacy route (including DELETE), so it must stay off for any real deployment.
* Rate limits and OTP lockouts live in process memory (per instance, reset on restart); a locked-out victim can be kept out by someone submitting wrong codes for their address (a trade-off of e-mail based lockout). Behind a proxy without `TRUSTED_PROXY_COUNT`, all users share one IP bucket (limits are generous for that reason).
* The OTP value is stored unhashed (no schema migration) and the session token is stored in `shared_preferences` on the device (plaintext on Android, local storage on web).
* The download links are valid for any holder for 5 minutes (signed, not single-use). The fallback stream endpoints `/videos/{id}/stream-raw` and `/download-processed` need a header, which a browser `<video>` element cannot send; the app uses them only when a video has no stored path, and on web that fallback will fail with 401.
* Dart server-URL override and absolute-URL handling (ATK-021), exp-file execution in `get_exp`, unpinned `pycocotools`, no `pip-audit` run, no TLS in the repo's nginx, `cloudflared.exe` binary, legacy React credentials, git history contents.
* CSV: the backend serves no CSV today, but if one is added, cells beginning with `= + - @` must be neutralised (the Excel generator already neutralises the video file name via `_text_cell`).
* The Docker, Android and CI changes are unbuilt; review them before relying on them.

---

## 7. Evidence: production refuses to start without configuration

Run from `backend/` with a temporary `DATABASE_URL` (excerpt of the real output):

```
$ APP_ENV=production python -c "import app.main"
RuntimeError: Refusing to start: insecure production configuration:
  - SMTP is not configured. Set SMTP_HOST and SMTP_FROM (...) so login codes can be e-mailed.
  - BACKEND_CORS_ORIGINS contains '*' which is not allowed in production. (...)     <- came from the local .env
  - DOWNLOAD_SIGNING_SECRET must be set to a random string of at least 32 characters (...)
exit=1

$ APP_ENV=production OTP_DEV_MODE=true BACKEND_CORS_ORIGINS="*" SMTP_HOST=h SMTP_FROM=f@x.test DOWNLOAD_SIGNING_SECRET=<40 chars> python -c "import app.main"
  - OTP_DEV_MODE is enabled but APP_ENV=production. Dev OTP delivery (...) is not allowed in production; ...
  - BACKEND_CORS_ORIGINS contains '*' which is not allowed in production. ...

$ APP_ENV=production BACKEND_CORS_ORIGINS=https://app.example.test SMTP_HOST=h SMTP_FROM=f@x.test DOWNLOAD_SIGNING_SECRET=<40 chars> python -c "import app.main as m; print(m.app.docs_url, m.app.openapi_url)"
None None
```

The same three cases run as real subprocesses in `test_production_config.py`.

---

## 8. Proposed GitHub Actions workflow (NOT created — for the owner to approve)

Suggested path `.github/workflows/security.yml`. Untested: the torch/whisper/yolox exclusion in the install step is my assumption from reading the imports (the tests never import torch; `model_loader` guards its torch import), so confirm the first run.

```yaml
name: security

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: Road-Distress-Management-System/backend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - name: Install (CPU-light: the tests never load torch / whisper / yolox)
        run: |
          grep -v -i -E '^(torch|torchvision|openai-whisper|pycocotools|thop|loguru|tabulate|tqdm|psutil)' requirements.txt > /tmp/requirements-ci.txt
          pip install -r /tmp/requirements-ci.txt -r requirements-dev.txt
      - name: Security test-suite
        run: python -m pytest tests/security

  static-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: Static security check (deferred items are allowed; use --strict as a release gate)
        run: python scripts/security_check.py

  dependency-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install pip-audit
      - name: Python dependencies
        run: pip-audit -r Road-Distress-Management-System/backend/requirements.txt

  flutter-analyze:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: mobile
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze --no-fatal-infos
      - run: flutter pub outdated || true
```

Add `--strict` to the static-check step (or a separate release workflow) once the keystore, `applicationId` and compose/legacy-frontend items are resolved. `pip-audit` may fail on packages without a published resolution for Python 3.12 (for example the torch pins); adjust once you see the first run.

---

## 9. Environment changes made by the defender

* Installed into the backend venv (dev-only, listed in `backend/requirements-dev.txt`): `pytest 9.1.1`, `httpx 0.28.1` and their dependencies `httpcore 1.0.9`, `iniconfig 2.3.1`, `packaging 26.3`, `pluggy 1.6.0`, `pygments 2.21.0`. `pip-audit` was **not** installed. No runtime dependency was added or changed.
* Scratch files (temp databases, probe scripts, backups of files restored after mutation checks) are in the session scratchpad directory only.
* No file in `uploads/`, `reports/`, `.env`, `*.db`, `.github/` or the legacy frontend was modified (mtimes checked); the tests redirect all storage to temp directories.

---

## 10. Blast radius (`git status` / `git diff --stat`)

59 tracked files modified (+1822 / -684; includes `docker-compose.yml`, `DEPLOYMENT.md` and `login_screen.dart`), plus new, untracked paths: `SECURITY.md`, `scripts/security_check.py`, `SECURITY_REPORTS/03_DEFENDER_REPORT.md`, and under `Road-Distress-Management-System/backend/`: `tests/` (conftest + 10 test modules), `pytest.ini`, `requirements-dev.txt`, `docker-entrypoint.sh`, and new modules `app/core/{env_guard,pagination,rate_limit,roles,safe_paths,security_headers,startup_checks,upload_checks,ws_auth}.py`, `app/db/bootstrap.py`, `app/services/{download_links,email_sender}.py`, `app/services/ai/model_status.py`.

Largest changes: `app/main.py` (router registry, seeding gates, health, handlers), `routes/reports.py` (signed links, confinement), `routes/live.py`, `routes/auth.py`, `services/otp_service.py`, `core/config.py`, `core/security.py`, `services/pdf_generator.py`, and the Dart data layer (`custom_http_client.dart`, `auth_*`, `live_detection_api.dart`, `reports_api.dart`, report call sites in `history_screen`, `reports_screen`, `video_review_screen`). Android: `main/AndroidManifest.xml` and `debug/AndroidManifest.xml`. Docs/config: `DEPLOYMENT.md`, `nginx.conf`, `Dockerfile`, `.dockerignore`.

Line endings: the working copy uses CRLF with `core.autocrlf`; files I rewrote with my tools are LF and git prints "LF will be replaced by CRLF" warnings for them. This does not change repository content.

---

## 11. Round 2 fixes

Triggered by the second supervisor review (containment clean, 241 tests independently reproduced). Issue 6 was deliberately not implemented (owner decision, see below).

**Honest note on process.** My first Round-2 pass was interrupted while I was running a mutation check. That check had temporarily edited three source files (`core/deps.py`, `core/config.py`, `routes/auth.py`) and the interruption left them mutated on disk. On resuming I inventoried the tree, found the mutations (for example `if True:` in the registration gate), restored the files from the backups taken before the mutation, and re-ran everything. The mutation check was then repeated with a script that restores the files in a `finally` block: four mutations (open registration gate, fail-open `is_production`, no dummy hash on login, ignored `TRUSTED_PROXY_COUNT`) made many Round-2 tests fail as intended, and the files were verified restored afterwards.

| Issue | Status | What changed | Tests (`tests/security/test_round2.py` unless noted) |
|---|---|---|---|
| 1 HIGH open self-registration | FIXED | `core/deps.py` `registration_gate`; `routes/auth.py` register depends on it. `ALLOW_SELF_REGISTRATION` (`core/config.py`): default true only in development, false otherwise. Without the flag: anonymous 401, non-admin 403, admin 201. Registered users always get `inspector`, even when an admin calls it and sends `role=admin`. Startup warning if the flag is on in production. `PUBLIC_ROUTES` comment updated (register is public only in development). `scripts/security_check.py` rule `open-registration`. | anonymous 401 for production/prod/staging/live; non-admin 403; admin creates `inspector` and cannot make admins; flag both ways; invalid session 401; the full route matrix repeated with the flag off (`test_every_route_rejects_anonymous_callers_in_locked_down_mode`) |
| 2 MEDIUM per-IP limits behind a proxy | FIXED in code (the owner must still set the variable on Railway) | `client_ip` uses the right-hand `X-Forwarded-For` entry (`hops[-N]`), never the spoofable left side; in production with `TRUSTED_PROXY_COUNT=0` the first request carrying `X-Forwarded-For` logs a CRITICAL message (once); the same advice is a startup-check warning (`collect_config_warnings`, returned by `validate_runtime_config`); `docker-compose.yml` sets `TRUSTED_PROXY_COUNT: "1"` with a comment; documented in SECURITY.md; `security_check.py` rule `proxy-config`. | `client_ip` parametrised including spoofed leftmost entries, fewer hops than proxies, junk requests; end-to-end: a rotating spoofed left entry cannot dodge the OTP IP limit; warning logged once and only in production; compose file asserted; startup warning |
| 3 MEDIUM fail-open APP_ENV | FIXED (strict handling chosen, startup does not fail on the name itself) | Only `development`, `dev`, `local`, `test` and empty (case-insensitive, trimmed) mean development; **any other value is treated as production** (strict rules, plus a warning for unrecognised names and a note in the startup error). `is_development` added; `is_production = not is_development`. Dev OTP is refused when `RAILWAY_ENVIRONMENT`, `RAILWAY_PROJECT_ID`, `RAILWAY_SERVICE_ID`, `DYNO`, `K_SERVICE` or `KUBERNETES_SERVICE_HOST` is set (non-empty) unless `ALLOW_DEV_OTP_ON_PLATFORM=true`; the startup warning states why. `security_check.py` rule `env-fail-open` (also flags direct `APP_ENV == "production"` comparisons). | `Production`, ` production `, `PROD`, `prd`, `staging`, `live`, `stage`, `productio`, `1` give strict behaviour; empty, whitespace, unset, `dev`, `DEV`, `development`, `local`, `test` give development; every marker; the override; the API withholds `dev_otp` when a marker is set; an empty marker is ignored |
| 4 MEDIUM unbounded counters | FIXED | `core/rate_limit.py`: `FailureLockout` and `SlidingWindowLimiter` sweep expired keys periodically (60 s) and enforce a hard cap of 10,000 keys, evicting the oldest first (active locks last). `verify_otp(account_exists=False)` records nothing per e-mail, so endless made-up addresses cannot grow state; they are still throttled per IP. To keep the response uniform, a per-e-mail lock now answers with the same 401 as any wrong code (it was 429, which would have separated real from unknown accounts); the per-IP lock still answers 429. | cap and sweep for both classes with a fake clock; an active lock survives a flood of other keys; limits still correct; 60 distinct unknown e-mails leave `email_lockout` and `email_request_limiter` empty; locked-versus-ordinary responses identical; unknown e-mails stay IP-throttled (`test_otp_login.py` updated) |
| 5 LOW login timing | FIXED (proven by counting PBKDF2 runs, not wall-clock timing, which would be flaky) | `/auth/login` verifies against a precomputed dummy hash (`core/security.py` `dummy_password_hash`, warmed at startup) when the user is unknown or the stored hash is the unusable marker or malformed (`is_usable_hash`), then decides with `usable and password_ok`; the 401 body is unchanged. | unknown, OTP-only and wrong-password logins each run exactly one full-cost PBKDF2 and return an identical body; the unusable-hash path calls the hasher |
| 7 LOW tightening | FIXED | Production-like startup errors in `startup_event` are re-raised (development unchanged). `null` CORS origin rejected (error in production, dropped in development). `DOWNLOAD_SIGNING_SECRET` rejected if shorter than 32 or fewer than 8 distinct characters. `GET /health` returns only `{"status":"healthy"}` (failures keep generic 500/503); table names and model details moved to the new authenticated `GET /api/v1/health/details`. Checked first: nothing in the Flutter app or the tests used `/health` details. | fatal versus swallowed startup error; `null` origin; weak and repetitive secrets (`test_production_config.py`); status-only health; details need a login; a test scans the Dart sources for `/health` |

**Verification of Round 2.** `pytest tests/security`: **322 passed**. `python scripts/security_check.py`: passes (same 5 deferred items, plus the three new rules clean). `import app.main` OK with `APP_ENV` unset. `flutter analyze --no-fatal-infos`: 0 errors, 17 issues, unchanged (no Dart code was changed in Round 2). Development smoke flow with `APP_ENV` unset (request-otp, verify-otp, /me, admin creates a user, that user creates project, audit, checklist item, chainage report and asset, legacy route 401 anonymous and 200 signed in, logout) behaved as expected, and development `/auth/register` stays open and still returns `inspector`. Not tested: Docker, a real Railway environment (platform markers are simulated with environment variables), a real proxy in front of the app.

**Behaviour changes from Round 2 the owner will notice**
* In production-like environments `POST /auth/register` needs an admin session (the app never calls it).
* Any `APP_ENV` other than development, dev, local, test or empty is now strict. If your Railway service has `APP_ENV` set to something unexpected, it needs SMTP and the other settings just like `production`.
* **On Railway (marker present) the dev OTP shortcut stops working even if `APP_ENV` is explicitly `development`** unless `ALLOW_DEV_OTP_ON_PLATFORM=true` (throw-away demos only). With `APP_ENV` unset the service is now production-like and refuses to start until configured: see section 12.
* Five wrong codes for an account now show the ordinary "invalid code" message (no distinct "too many attempts" for the per-e-mail lock).
* `/health` no longer lists tables or model files; use `/api/v1/health/details` with a login. A deployment health check must rely on the status code.
* A weak or repetitive `DOWNLOAD_SIGNING_SECRET`, or a `null` CORS origin, aborts a production start.

**Owner decisions and actions (additions to section 4)**
* Set `TRUSTED_PROXY_COUNT=1` on Railway (and keep it equal to the number of proxies elsewhere).
* Decide whether to allow public sign-up (`ALLOW_SELF_REGISTRATION`); recommendation: leave it off.
* **Issue 6 (not implemented, needs your decision): the demo admin in an existing production database.** `admin@roaddistress.org` (user id 1) probably exists in the Railway database from the old startup seed. Anyone who controls or can receive mail at that address could log in as admin once SMTP is on, and until then the dev OTP exposes it. Recommendation: before switching to production set `BOOTSTRAP_ADMIN_EMAIL` to your own mailbox, log in as that new admin, then either delete user 1 (`DELETE /users/1`) or change its e-mail to a mailbox you control; optionally add a rule that disables OTP login for the legacy demo address in production. Rotate anything that used the old default password.
* Everything listed in section 4 still applies.

---

## 12. Final fixes (supervisor gate)

* **Gap A - fixed.** `app/core/config.py`: `APP_ENV` now defaults to empty. An empty/unset `APP_ENV` means development only when no hosting-platform marker (`RAILWAY_ENVIRONMENT`, `RAILWAY_PROJECT_ID`, `RAILWAY_SERVICE_ID`, `DYNO`, `K_SERVICE`, `KUBERNETES_SERVICE_HOST`) is present; with a marker it is production-like (`app_env_implicit_production`) for ALL dev defaults: open self-registration off, `/docs` off, demo seeding off, mock model off, CORS must be explicit, dev OTP off, and the full production start-up checks apply (SMTP, signing secret, no `*` CORS). An explicit `APP_ENV=development|dev|local|test` on a platform remains the owner's choice (docs, open registration, demo data on; the dev OTP shortcut is still refused unless `ALLOW_DEV_OTP_ON_PLATFORM=true`). A laptop with nothing set behaves exactly as before. The startup error and warnings say why. Tests: `tests/security/test_platform_defaults.py` (every marker x unset/blank `APP_ENV`; explicit development names; no marker; empty marker values; API-level anonymous registration 401 / admin 201 / explicit development reopens; real subprocesses: marker + unset refuses to start without configuration, starts with docs hidden when configured, marker + `development` starts with docs, no marker + unset unchanged).
  **Consequence for the current Railway service:** if it runs with `APP_ENV` unset, the next deploy will REFUSE TO START (missing SMTP / `DOWNLOAD_SIGNING_SECRET`) until you either complete the production configuration in section 4 (recommended) or set `APP_ENV=development` explicitly to keep the old demo behaviour.
* **Gap B - fixed.** `core/rate_limit.py`: the full O(n) sweep now runs only on the time interval; the hard cap is enforced per insert by evicting the oldest key (for `FailureLockout`, the oldest *unlocked* key first). Test `test_over_cap_insert_does_not_scan_every_key` plus the existing cap, sweep and lock-survival tests pass.
* **Doc drift - fixed.** Section 10 counts corrected (59 modified files after the final edits, including `docker-compose.yml` and `DEPLOYMENT.md`). `DEPLOYMENT.md` section 6 no longer points at `/api/v1/docs`; it describes `/health` (status only) and the authenticated `/api/v1/health/details`. `SECURITY.md` documents the platform-aware `APP_ENV` default.
* **Login screen hint - done, Dart only.** `login_screen.dart`: the code-entry step now reads "If this email is registered, a login code has been sent. Check your inbox." (neutral, no account-existence leak, no backend change). `flutter analyze --no-fatal-infos`: 0 errors, 17 issues (unchanged).
* **Owner action added:** when e-mail delivery is not configured (or fails), the app shows no error at all: the server answers `sent: true` on purpose and logs the failure ("Cannot deliver login code: SMTP is not configured" / "OTP e-mail could not be delivered"). Check the server logs when a user says no code arrives, and send yourself a test login after configuring SMTP.

**Final verification:** `pytest tests/security` 348 passed; `scripts/security_check.py` passes; `import app.main` clean; `flutter analyze --no-fatal-infos` 0 errors / 17 pre-existing issues.
