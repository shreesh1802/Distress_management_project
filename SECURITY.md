# Security

This document covers how to run the project's security safeguards, how to report a problem, the
production configuration the backend requires, and the checklist to complete before submitting the
Android app to Google Play. The detailed findings and what was changed are in
`SECURITY_REPORTS/03_DEFENDER_REPORT.md`.

## Reporting a vulnerability

Please do **not** open a public issue for a security problem. Report it privately to the project
owner (add a monitored security contact address here before publishing the repository or the app:
`SECURITY_CONTACT = <owner to fill in>`) with the affected route/screen, the steps to reproduce and
the impact. Expect an acknowledgement within a few days.

## Safeguards that must stay green

| What | How to run | Notes |
|---|---|---|
| Backend security test-suite (auth matrix, roles, path confinement, OTP, sessions, IDOR, uploads, live WebSockets, production start-up) | `cd Road-Distress-Management-System/backend` then `pip install -r requirements.txt -r requirements-dev.txt` then `python -m pytest tests/security` | Runs in-process against a **temporary SQLite database**; never touches `road_distress.db`, `uploads/` or `reports/`. |
| Static security check (stdlib only, offline) | `python scripts/security_check.py` (add `--strict` to also fail on knowingly deferred items) | Fails on TLS bypass outside `kDebugMode`, cleartext traffic in the main manifest, debug-signed release builds, wildcard CORS, unguarded `weights_only=False`, SQL built with f-strings, `shell=True`, committed secrets/keystores/databases, secret patterns. Deferred items are listed in the script with a justification. |
| Dependency vulnerabilities | `pip-audit -r Road-Distress-Management-System/backend/requirements.txt` and `flutter pub outdated` | Needs network access; run in CI. |
| Dart static analysis | `cd mobile && flutter analyze --no-fatal-infos` | |

A new route that is reachable without a login makes `test_route_auth.py` fail until it is added,
deliberately and with a reason, to `PUBLIC_ROUTES` in that file.

## Deployment modes (`APP_ENV`)

`APP_ENV=development` (also `dev`, `local`, `test`, or empty/unset on a developer machine) behaves like the original local demo: the login code is returned
in the API response (`dev_otp`), CORS is open, demo data is seeded, the mock detector is allowed and
`/docs` is available. **Never run an internet-facing deployment in this mode.**

**`APP_ENV` fails closed.** An unset/empty `APP_ENV` is development ONLY when no hosting-platform marker is present; on Railway, Heroku (`DYNO`), Cloud Run (`K_SERVICE`) or Kubernetes it is treated as production-like for every dev default (dev OTP, open self-registration, `/docs`, demo seeding, mock model, wildcard CORS), so the service will refuse to start until it is configured - set `APP_ENV=production` (or, deliberately, `APP_ENV=development`, which is then your explicit choice and keeps docs/open registration/demo data; the dev OTP stays refused on a platform unless `ALLOW_DEV_OTP_ON_PLATFORM=true`). Only the exact development names above (case-insensitive, whitespace ignored) mean development. ANY other non-empty value - `production`, `prod`, `staging`, `live`, `prd`, a typo - gets the strict production rules (and an unknown name additionally logs a warning). The dev OTP shortcut is also refused whenever a hosting-platform marker is present (`RAILWAY_ENVIRONMENT`, `RAILWAY_PROJECT_ID`, `RAILWAY_SERVICE_ID`, `DYNO`, `K_SERVICE`, `KUBERNETES_SERVICE_HOST`) unless you set `ALLOW_DEV_OTP_ON_PLATFORM=true` (throw-away demos only; the start-up log explains why it was refused).

`APP_ENV=production` (recommended for every deployment) then **refuses to start** (clear error in the
log) unless the configuration below is complete.

| Variable | Production | Purpose |
|---|---|---|
| `APP_ENV` | `production` | Selects the secure posture. Dev OTP is never returned or logged, `/docs` + OpenAPI are disabled, demo seeding and the mock model are off. |
| `DATABASE_URL` | required | e.g. the Railway Postgres URL. There is no default password any more (`POSTGRES_*` variables are still supported). |
| `SMTP_HOST`, `SMTP_FROM` | **required** | Provider-neutral e-mail delivery of login codes (stdlib `smtplib`). |
| `SMTP_PORT` | optional (587) | 465 uses implicit TLS. |
| `SMTP_USER`, `SMTP_PASSWORD` | as your provider requires (set both or neither) | |
| `SMTP_STARTTLS` | optional (true) | |
| `DOWNLOAD_SIGNING_SECRET` | **required**, >= 32 characters with at least 8 distinct ones (a repeated character is rejected) | Signs the 5-minute report download links. Generate with `python -c "import secrets; print(secrets.token_urlsafe(48))"`. |
| `BACKEND_CORS_ORIGINS` | optional | Comma separated exact web origins. Unset = no cross-origin access (native apps and a same-origin web build do not need CORS). `*` and `null` are rejected in production. |
| `BOOTSTRAP_ADMIN_EMAIL` | recommended once | A mailbox you control; an admin account with this e-mail is created at start-up if it does not exist. Nothing is auto-created without it. |
| `REVIEWER_EMAIL`, `REVIEWER_CODE` | optional, **set together** (both unset = off) | App-store reviewer access. The account with `REVIEWER_EMAIL` (always created as a non-admin `employee`, added to a small "Demo Project (app review)") can sign in with the fixed 6-digit `REVIEWER_CODE` instead of an e-mailed code. Refused for any admin account; no e-mail is ever sent to it; wrong guesses lock it like any other account (5 tries / 15 min). The code must be exactly 6 digits with at least 4 distinct digits, and the address must not be the bootstrap/demo admin or startup fails. Give both to Google in Play Console > App access, and **remove both variables after approval** (or rotate the code). Note: like every signed-in user, the reviewer can read the shared legacy M1 data (videos/detections/reports); use a production database without real survey data while the reviewer code is active, or accept that exposure. |
| `TRUSTED_PROXY_COUNT` | **`1` on Railway**, behind nginx or Cloudflare (set it to the number of proxies in front of the app) | Lets per-IP rate limits use the real client address from `X-Forwarded-For` (the right-hand entry; the left side is client-controlled and ignored). With the default `0` every user behind one proxy shares one address, so a few failed attempts lock everyone out; production logs a start-up warning and a CRITICAL message the first time it sees an `X-Forwarded-For` header in that state. `docker-compose.yml` sets it to `1` for the nginx setup. |
| `ALLOW_SELF_REGISTRATION` | unset (off outside development) | `POST /auth/register` needs an admin session unless this is `true`. Default is `true` only in development. Open registration lets anyone who owns a mailbox obtain a login that works on every signed-in route, so leave it off. Accounts always get the non-admin `inspector` role; use `POST /users/` (admin) for other roles. |
| `ALLOW_DEV_OTP_ON_PLATFORM` | unset | `true` allows the dev OTP shortcut on a hosting platform (see above). Never for a real deployment. |
| `SEED_DEMO_DATA` | unset (off in production) | `true` re-enables the demo video 20 / 8 demo detections. |
| `ALLOW_MOCK_MODEL` | unset (off in production) | `true` allows random fake detections when the YOLOX weights are missing. Leave off for real use; the model status is in the authenticated `GET /api/v1/health/details`. |
| `OTP_DEV_MODE` | **must stay unset/false** | Setting it to true in production makes start-up fail. |
| `YOLOX_ALLOW_UNSAFE_CHECKPOINT` | unset | Only for a checkpoint that cannot be loaded in weights-only mode and that you fully trust. |
| `LIVE_MAX_FRAME_BYTES`, `LIVE_MAX_FRAME_DIMENSION` | optional (4 MB, 4096 px) | Limits for frames pushed over the phone-camera WebSocket. |

`GET /health` is status-only (`{"status":"healthy"}`; the HTTP status carries failures). Table names and AI-model details are in the authenticated `GET /api/v1/health/details`. In production a failure during start-up (database unreachable, bootstrap error) stops the process instead of being logged and ignored.

Abuse limits (OTP attempts, request rates) are kept **in process memory**: they are per instance and
reset on restart; their key tables are size-capped and swept so they cannot be used to exhaust memory. A per-e-mail OTP lock is only kept for real accounts and looks exactly like a wrong code (the per-IP lock answers 429). Put a shared limiter (nginx `limit_req`, Cloudflare, Redis) in front for several
instances.

### TLS, HSTS and CSP (nginx guidance)

Terminate TLS in front of the app (a platform load balancer, Cloudflare, or nginx with a certificate)
and only then add, inside the `server { ... }` block of `nginx/nginx.conf`:

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer" always;
# The Flutter web build (CanvasKit/wasm) needs a tailored policy; start in report-only mode and tighten:
add_header Content-Security-Policy-Report-Only "default-src 'self'; img-src 'self' data: blob: https:; media-src 'self' blob: https:; connect-src 'self' https: wss:; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'" always;
```

The backend itself sets `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` and
`Cache-Control: no-store` (API responses) but deliberately no HSTS/CSP.

## Android release (Google Play) checklist

Items marked **OWNER** cannot be done in the repository.

1. **OWNER** Choose the final `applicationId` (currently the placeholder `com.example.mobile`, rejected by Play) in `mobile/android/app/build.gradle.kts`, and update `namespace`/`MainActivity` package accordingly. It cannot be changed after the first Play upload.
2. **OWNER** Create an upload keystore outside the repository and a `mobile/android/key.properties` (template: `key.properties.example`; steps in `mobile/ANDROID_RELEASE.md`). The Gradle signing config is already wired: with `key.properties` the release build is signed with it; without it `flutter build appbundle --release` **refuses to run** (an APK still falls back to the debug key for personal test installs). `key.properties`, `*.jks`, `*.keystore` are git-ignored. Use Play App Signing.
3. Build with an HTTPS backend: `flutter build appbundle --release --dart-define=API_BASE_URL=https://<your-backend>`. Release builds no longer allow plain HTTP (`usesCleartextTraffic="false"`) and no longer skip TLS validation (`kDebugMode` only).
4. Backups are disabled (`allowBackup="false"`); the label is "Road Inspection". Verify with `apkanalyzer manifest print` and `apksigner verify --print-certs` that the AAB/APK is not debug-signed.
5. **OWNER** Data Safety form: collected data = e-mail address, name, audio recordings (audit commentary), camera frames (live detection), uploaded media/documents, approximate/precise location if GPS is used. Data is encrypted in transit; users can request deletion.
6. **OWNER** Publish a privacy policy URL and link it in the app and in the Play listing.
7. Account deletion: **done.** In-app "Delete account" (project list header and the dashboard menu; the user types their own e-mail to confirm) calls `POST /auth/delete-account`, which removes the account, sessions, pending codes and project memberships, and re-attributes records in shared projects to a "Deleted user" placeholder that cannot sign in (`app/services/account_deletion.py`). The last administrator cannot delete themself. **OWNER:** enter the web page `docs/privacy/delete-account.html` (deploy it next to the privacy policy) as the deletion URL in Play Console > Data safety.
8. Permissions to justify in the declaration: `CAMERA` (live detection), `RECORD_AUDIO` (audit commentary), `INTERNET`, `READ/WRITE_EXTERNAL_STORAGE` (legacy file access, write is capped to API 28), `WAKE_LOCK`, `ACCESS_NETWORK_STATE`.
9. Reviewer access: **done** via `REVIEWER_EMAIL` + `REVIEWER_CODE` (see the table above). **OWNER:** choose the values, set them in Railway, enter them in Play Console > App access, and remove them once the app is approved. Do not re-enable `OTP_DEV_MODE` in production.
10. Remove the public APK download from the store build's update path: `/download-apk` and `/app-release.apk` (and `uploads/RoadDistress.apk`) are for sideloading only. Delete them from the production server before publishing.
11. Keep Flutter/Gradle/Android dependencies current; run `flutter pub outdated` and the Play pre-launch report.

## Known residual risks (see the defender report for the full list)

* `/uploads` is still a public static mount; files are protected only by unguessable names for audio/assets (video and detection images are not unguessable). Replacing it with signed URLs is a planned redesign.
* Anyone who can sign in (an admin-created account, or any self-registered one if you enable `ALLOW_SELF_REGISTRATION`) can use the legacy M1 endpoints (videos, distress records, reports, maintenance, live detection) - there is no per-user or per-project scoping on them yet.
* Session tokens are kept in `shared_preferences` on the device (`flutter_secure_storage` is a planned follow-up).
* Rate limits are per process.
* CSV downloads, if ever added, must neutralise formula injection (leading `= + - @`); the Excel report generator already does for file names.
