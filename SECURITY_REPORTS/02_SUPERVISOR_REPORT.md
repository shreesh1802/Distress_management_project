# 02 — Supervisor Report (audit of the Attacker's report)

**Role:** read-only supervisor. Checked the attacker's containment, report hygiene, and every finding against the real code; produced the vetted handoff for the defender.
**Result in one line:** no containment breach and no leaked secrets. All 30 findings point at real code. Two statements would mislead the defender: the claim that the Flutter app does not use the `/users` routes (it does), and an overstatement in ATK-027.

## 1. Containment verdict: CLEAN

| Check | Result |
|---|---|
| HEAD | `0521a84230194ee1410fea12a310cad8ab062f34`, branch `main` (matches baseline) |
| `git status --porcelain` | exactly `?? SECURITY_REPORTS/` (the coordinator's own file) |
| Stash | one pre-existing entry from 2026-08-14 (predates this run) |
| Branches / reflog | nothing newer than the 2026-09-17 commit; no `.git/index.lock` |
| Files newer than the attacker report | none |
| Other recently modified files | two gitignored Flutter-generated `Package.swift` files (ios/macos ephemeral), written at 10:41 before the report existed — consistent with the owner's earlier Flutter run, not a breach |
| Sensitive local files | `road_distress.db`, `.env`, `cloudflared.exe` mtimes show no attacker writes |

Attacker's disclosed actions (read-only SQLite counts, sha256 of `cloudflared.exe`, `.venv` dist-info listing, one grep that wandered into `.venv`): all within the rules. The sha256 was recomputed and matches. No network-derived claims; all paths inside the repo; version spot-checks match `.venv` metadata.

## 2. Report hygiene verdict: PASS
No full secret, token, tunnel hostname or personal email in the attacker report. Secrets are shown as first 4 characters + `****`. Only full identifiers: a sha256 (allowed) and `admin@akcm.com` (a hardcoded mock-login literal in repo source, not a person). Session-token figure is a count only.

## 3. Verification of the 30 findings

| ID | Verdict | Evidence |
|---|---|---|
| 001 | CONFIRMED (Critical) | `users.py:15-58`: all 5 routes depend only on `get_db` |
| 002 | CONFIRMED (Critical) | `auth.py:48-59` no auth; `schemas/user.py:24` free-text role; `crud/user.py:41` stores it |
| 003 | CONFIRMED (Critical) | `otp_service.py:32` dev default on; `:52` logs, `:53` returns code; `:59-64` stub raises; `auth.py:68,84` returns `dev_otp`; login screen renders it. With dev mode off nobody can log in, so a live deployment is almost certainly in dev mode |
| 004 | CONFIRMED (Critical) | `upload.py:64` builds path unsanitised; `schemas/video.py:40,46-47` client-writable path fields; `videos.py` / `services/video.py:175,187` join into `FileResponse` / `os.remove`; an absolute path discards the base |
| 005 | CONFIRMED (Critical) | `get_current_user` used only in auth `/me`, projects, audits, assets; Dart sends `Authorization` only in `asset_api`, `audit_api`, `project_api`, `auth_api` |
| 006 | CONFIRMED (High) | `otp_service.py:36` `random.choices`; no attempt counter; verify matches across all unused rows (`:71-76`) |
| 007 | CONFIRMED (High) | `http_overrides_io.dart:13-14` `badCertificateCallback => true`, installed from `main.dart:12` (web stub is a no-op) |
| 008 | CONFIRMED (High) | `live.py:41-191` no auth; `:89-93` returns in `try`, `finally` at `:135` still calls `manager.stop()` |
| 009 | SEVERITY-ADJUSTED to Medium | `main.py:316` mounts `/uploads` unauthenticated; audio/documents use UUID names (not enumerable); video paths listable only via unauthenticated `GET /videos/` (covered by ATK-005) |
| 010 | CONFIRMED (High while 005 is open) | `/videos/storage/summary` walks disk; `/auth/login` PBKDF2 100k; no rate limiting; 500 MB cap checked after multipart spooling |
| 011 | CONFIRMED (High as release blocker) | `build.gradle.kts:19` `com.example.mobile`, `:32` debug signing; manifest `usesCleartextTraffic="true"` `:9`, no `allowBackup`/network security config |
| 012 | CONFIRMED (Medium) | `models/auth.py:35` plaintext token, 30-day TTL, no logout route; `auth_provider.dart:105,124` token in `shared_preferences`, local-only logout |
| 013 | CONFIRMED (Medium, arguably Low) | `auth.py:81-84` differs known vs unknown; `:53-58` says email exists; `GET /users/` lists everyone |
| 014 | PARTIAL (Low-Medium) | `require_admin` unused; free-text roles; owner never inserted into `ProjectMember` (functional list bug, not an authorization hole) |
| 015 | PARTIAL (Low-Medium) | `main.py:35` hardcoded `*`, `BACKEND_CORS_ORIGINS` unused; nginx port 80 only; Swagger UI not proxied by nginx but reachable on direct uvicorn (e.g. Railway); openapi.json proxied |
| 016 | SEVERITY-ADJUSTED to Low | placeholder hash + plaintext fallback real, but `/auth/login` returns no token; real danger = predictable admin email + ATK-003 |
| 017 | CONFIRMED (Low) | `main.py:262`, `reports.py:72,107`, `videos.py`, `services/video.py:117` |
| 018 | SEVERITY-ADJUSTED to Low-Medium | no `USER`, `COPY . .`, `.dockerignore` omits `.env`, `*.db`, `scripts/*.exe`; a copied dev `.env` `DATABASE_URL` would override Compose `POSTGRES_*` |
| 019 | PARTIAL (Low-Medium) | raw `video.filename` in `Paragraph`; `detection_image_path` client-writable and joined into `Image()`; ReportLab fetch behaviour UNVERIFIABLE statically |
| 020 | CONFIRMED (Medium) | `model_loader.py` falls back to `MockYOLO` with random boxes |
| 021 | PARTIAL (Low-Medium) | `startsWith('http')` resolvers real; override dialog accepts any URL; bearer token is NOT attached to resolved data URLs (only to the base URL the user typed) — token-to-third-party claim overstated |
| 022 | CONFIRMED (Low) | `npx -y` with `shell=True`, `StrictHostKeyChecking=no`, `0.0.0.0` bind; exe unreferenced; sha256 matches |
| 023 | CONFIRMED (Low) | extension-only checks; raw client `content_type` stored for assets |
| 024 | CONFIRMED (Low) | `torch.load(..., weights_only=False)`; paths from env/repo |
| 025 | CONFIRMED (Low) | 100k PBKDF2, `==`, check-then-set OTP |
| 026 | CONFIRMED (Low/Info) | legacy React literal creds; nginx serves the Flutter build |
| 027 | PARTIAL (Low) | tunnel hostnames in 6 commits (not 3); committed detection JPEGs; unguarded `seed_data.py`. Overstated: startup only rewrites user 1's `full_name`; admin role set only when user 1 is created |
| 028 | CONFIRMED (Low) | unbounded `interval_km` (capped at 500 buckets); `member_emails` no max length. Citation fix: `schemas/project.py:19`, not `:93` |
| 029 | CONFIRMED (Info) | `pycocotools>=2.0.2` unpinned; installed versions match |
| 030 | CONFIRMED (Info) | merged release manifest adds RECORD_AUDIO, READ_EXTERNAL_STORAGE, WAKE_LOCK, ACCESS_NETWORK_STATE |

**"Found safe" claims tested (11): all hold** (SQL `text()` static; projects/audits/assets authorization; StaticFiles traversal; token generation; report download paths; upload filename handling; no app-code outbound HTTP/subprocess; iOS ATS; git never held `.env`/`*.db`/keystores; Excel generator). Imprecise wording: "only launcher activity exported" (a `ProfileInstallReceiver` is also exported but `DUMP`-permission guarded) and "symlinks not followed" (in-tree symlinks resolve, escaping ones are rejected).

## 4. Errors in the attacker report
No finding is a false positive. Corrections:
1. **ATK-001 fix note is wrong and dangerous:** the app *does* call `GET /api/v1/users/` (`maintenance_api.dart:82`, `MaintenanceApi.fetchUsers`, feeding `maintenance_screen.dart` and `reports_screen.dart:119`). Locking the whole router breaks those screens.
2. ATK-027 overstates "forces user 1 to be admin". 3. ATK-021 overstates token exposure.
4. Severity calls: 009 → Medium, 016 → Low, 018 → Low-Medium, 015 (Swagger UI not reachable via nginx).
5. Citation errors: `schemas/project.py:93`; ATK-027 commit list incomplete.

## 5. Issues the attacker missed

| ID | Sev | Issue | Evidence |
|---|---|---|---|
| SUP-001 | Low | Any authenticated user can attach arbitrary registered accounts to a project; `member_emails` in the response is an enumeration oracle; a non-admin owner cannot list their own new project (list joins `ProjectMember` only) | `crud/project.py:24-34,62-65` |
| SUP-002 | Low | Email normalization mismatch: OTP rows keyed lowercase/stripped (`otp_service.py:48,69`) but user lookup is exact-case (`crud/user.py:24`) and registration does not normalize (`:39`); case-variant accounts share OTP codes | `auth.py:80,100` |
| SUP-003 | Low | `skip`/`limit` have no maximum on `/users/`, `/distress/`, `/videos/`, `/reports/`, `/upload/videos` | route signatures |
| SUP-004 | Info | Predictable seeded admin email (`admin@roaddistress.org`) + dev OTP = instant admin takeover; treat ATK-003 as top priority | `main.py:159` |
| SUP-005 | Info | `whisper.load_model` downloads weights at runtime; ffmpeg copied into `.cache/` at runtime — pin model, prefer baking in | `transcription_service.py` |

## 6. Defender handoff (ordered by risk)

| # | IDs | Fix direction | Breakage risk / notes |
|---|---|---|---|
| 1 | 004 | Confine every stored-path read/delete to the uploads (or reports) root; split client PUT schema from internal one | LOW. Keep path fields on an internal schema: `detection_service.py:39` and `pipeline_manager.py:328` write `processed_filepath` via `UploadedVideoUpdate`. Demo seed paths must still resolve |
| 2 | 002 | Server-side role on register (enum, ignore client role); `UserUpdate.role` admin-only | LOW. App never calls `/auth/register`; `test_user_crud.py`, `test_video_upload.py` need updating |
| 3 | 006, 025, 013 | `secrets.randbelow`; one active code per email; per-email attempt counter + lockout; hash codes; `hmac.compare_digest`; atomic mark-used; same response for known/unknown emails | LOW-MEDIUM. Model change needs migration; app's `requestOtp` already tolerates null `dev_otp` |
| 4 | 003 | Real email delivery; remove `dev_otp`/code logging outside local dev; fail closed in production. **NEEDS-OWNER-DECISION:** email provider, Railway `OTP_DEV_MODE`, Play reviewer test-login mechanism | HIGH. Flipping the flag before email exists locks everyone out |
| 5 | 001 | `POST/PUT/DELETE /users` → `require_admin`; `GET /users/` → `get_current_user` with reduced response | MEDIUM. `MaintenanceApi` has no token field; must be given one |
| 6 | 005, 010 | `get_current_user` on videos, upload, distress, gis, reports, maintenance, detection; then project scoping | HIGH for the app. These Dart classes must send the bearer token first: `video_api.dart:111`, `road_distress_api.dart:95`, `gis_api.dart:153`, `analytics_api.dart:27`, `maintenance_api.dart:67`, `reports_api.dart:211`, `live_detection_api.dart:192`, and `mjpeg_view.dart:46` (raw `http.Client`) |
| 7 | 008 | Authenticate `/live` HTTP + WebSocket; fix `finally` so only the owning connection calls `stop()`; cap frame size | MEDIUM-HIGH. Browser WebSockets cannot set headers: use first-message token or short-lived ticket, not a URL token. nginx must forward the `phone-stream` upgrade |
| 8 | 009 | Serve `/uploads` and report download/preview via access-checked or signed URLs | HIGH if naive: many Dart callers fetch by bare URL (`Image.network`, `VideoPlayerController.networkUrl`, `launchUrl`, `AudioPlayer UrlSource`). Use signed URLs |
| 9 | 007 | Remove `badCertificateCallback`, or restrict to debug builds/named hosts | MEDIUM. Tunnel/self-signed dev hosts will fail TLS in release |
| 10 | 011 | Real application ID, `allowBackup=false`, cleartext off/network security config, proper label. **NEEDS-OWNER-DECISION:** release keystore (owner creates, stored outside repo) and final application ID | MEDIUM. New application ID = new app identity; cleartext off breaks plain-HTTP LAN/tunnel dev flow |
| 11 | 012 | Server-side logout; store token hashes; purge expired rows; shorter TTL; secure storage on device | MEDIUM. Token hashing invalidates existing sessions |
| 12 | 002/014/SUP-001 | Role enum, admin-only actions, owner visible in own project list | LOW |
| 13 | 016, 027 | Remove placeholder seeding and plaintext fallback; guard `seed_data.py` and demo seeding behind an env flag; rotate/retire default credentials. **NEEDS-OWNER-DECISION:** rotating real credentials and any git-history rewrite — do not rewrite history or change Railway env unilaterally | MEDIUM. Demo video 20 seed may be relied on |
| 14 | 015, 017, 018 | Explicit CORS origins, security headers, non-root Docker `USER`, `.dockerignore` additions, generic errors | LOW-MEDIUM. Non-root needs writable `uploads/`/`reports/` volumes |
| 15 | 019–029, SUP-001/002/003/005 | Escape PDF markup + confine image paths; `MockYOLO` demo-only; restrict absolute-URL/server-override handling; magic-byte checks; constrained schema types; `pip-audit`; retire legacy React app and `cloudflared.exe`; normalize emails; cap pagination | LOW. Removing `MockYOLO` could break demos run without weights |

## 7. Overall assessment of the attacker: reliability HIGH
30/30 findings point at real code (22 fully correct, 7 real but over/under-rated or partly overstated, 1 unverifiable statically). Headline Critical/High items hold; the "found safe" list survived every challenge; secrets handling and read-only conduct were clean. Its one materially harmful error was the claim that the app does not use the users routes — rely on this report's handoff for that item.
