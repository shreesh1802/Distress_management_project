# 04 — Supervisor Review of the Defender's Changes (Round 2)

**Role:** read-only supervisor reviewing the defender's uncommitted changes (57 modified + ~20 new files) before the owner commits. The supervisor re-ran the tests and checks itself and wrote throwaway in-process probes against temp SQLite files; it did not run `flutter test`, Docker or an Android build.
**Reviewed state:** HEAD `0521a84230194ee1410fea12a310cad8ab062f34`, nothing staged, nothing committed.
**Verdict:** safe to commit AFTER the issues below are fixed (one more pass). Confidence ~85%. See `03_DEFENDER_REPORT.md` for the "Round 2 fixes" section covering these issues.

## 1. Containment: CLEAN
| Check | Result |
|---|---|
| HEAD / staging / stash | HEAD unchanged, nothing staged, `stash@{0}` is the pre-existing 2026-08-14 entry |
| `.github\`, `requirements.txt`, `build.gradle.kts`, `pubspec`, legacy React frontend | untouched (no `.github\` created; no `applicationId`/signing change) |
| `.env`, `*.db`, `uploads\`, `cloudflared.exe`, reports 01/02 | untouched (mtimes predate the run) |
| venv | only the disclosed dev-only installs: pytest 9.1.1, httpx 0.28.1 (+ deps) |
| Files outside the defender's rules | none |

## 2. Backdoor / weakening scan
No backdoor found: no hardcoded tokens/keys, no `or True`, no over-broad allow-list, nothing logs OTP codes or tokens (every logger call grepped). Three fail-open weaknesses were found (APP_ENV fallback, per-process random signing-secret fallback when unset in dev, swallowed startup errors) — see issues below.

## 3. Key-fix review
| Area | Verdict | Note |
|---|---|---|
| `safe_paths.py` path confinement | OK | NUL, `/`, `\`, drive letters, UNC, absolute paths rejected; `realpath` + `commonpath` (so `/uploads_evil` doesn't match); every `FileResponse`/`os.remove`/`open`/`Image` on DB-stored paths goes through it |
| OTP (`otp_service.py`, `auth.py`, `rate_limit.py`) | OK with issues | CSPRNG, single active code, atomic mark-used, `hmac.compare_digest`, email normalization, nothing logged; issues 2, 4, 5 below |
| Session tokens | OK | SHA-256 at rest, 7-day TTL, logout revokes, expired rows purged at login; password/role changes do not revoke sessions (minor) |
| Signed download links | OK | HMAC-SHA256 over `purpose:id:expiry`, constant-time compare, 5-minute expiry, bound to resource + purpose; not single-use (disclosed) |
| WebSocket first-message auth + live fixes | OK | `accept()` then 5 s-timeout auth; model manager touched only after auth; `owns_session` finally-fix present; 4 MB frame cap + header-dimension pre-check |
| Route authentication | ISSUE | Every non-public route returns 401 anonymously (public: `/health`, `/api/v1/health`, `POST /auth/{login,register,request-otp,verify-otp}`, `/download-apk`, `/app-release.apk`, `/uploads` mount; docs only in dev). But see issue 1 |
| Startup checks / dev defaults | OK, issue 3 | Complete production config starts; `CORS="https://a.test, *"` rejected; dev start with `APP_ENV` unset and `.env` `CORS=*` still works |
| users / roles | OK | writes admin-only; `GET` returns `UserPublic`; register ignores `role` (probe: `role:admin` -> `inspector`) |
| Uploads | OK | magic bytes only for pdf/png/jpg/docx/xlsx/wav; audio/csv/txt pass on extension; content type derived from extension |
| PDF / model loader / schemas | OK | all user strings escaped; images confined; mock model gated; schema limits match what the Flutter app sends |
| Docker | OK by reading (unbuilt) | non-root uid 10001, entrypoint chowns volumes, `.dockerignore` correct, nginx WS location valid |

## 4. App compatibility
- All API classes use `CustomHttpClient`, which attaches the bearer token only to requests matching the configured backend scheme/host/port; `mjpeg_view` switched to it. A 401 on a token-bearing request signs the user out to the login screen.
- WebSocket first-frame format `{"type":"auth","token":…}` matches on both sides for `/live/ws` and `/live/phone-stream`.
- Reports use `POST /reports/{id}/download-link?kind=…` then the absolute signed URL.
- `flutter analyze --no-fatal-infos`: 0 errors, 17 pre-existing issues.
- `flutter test`: the 3 failures (login-screen widget test looking for "Administrator Access" which appears nowhere in `lib/`; two `DetectionsSidebar` overflow tests in an untouched file) were judged plausibly pre-existing by reading; not confirmed against a baseline.
- Likely runtime effects: old app builds / the running :5173 dev server get 401s until rebuilt; release/profile Android builds are HTTPS-only (sideloaded release APKs pointing at `http://LAN` stop working; debug keeps cleartext); `/videos/{id}/stream-raw` and `download-processed` do not work in a browser `<video>` (works on mobile); all sessions invalidated.

## 5. Independent test results
| Check | Result |
|---|---|
| `pytest tests/security` (temp DB) | **241 passed**, 0 failed, ~55 s |
| `scripts/security_check.py` | passed; same 5 deferred items (com.example applicationId, debug-key release signing, two compose password literals, legacy React login) |
| `flutter analyze` | 0 errors, 17 issues |
The route-auth test is meaningful (walks real routes incl. included routers, cross-checks OpenAPI, requires ≥40 routes, asserts exactly 401 anonymously and with a bad token, pins the public allow-list). The four regressions the defender re-introduced are each covered by a plausible test. Gaps at review time: `client_ip` / `X-Forwarded-For` handling, lockout DoS, `APP_ENV` typo values.

## 6. Defender claim audit (selected)
Accurate: ATK-001, 002, 003 (dev default stays fail-open), 004, 006 (lockout DoS disclosed), 007 (not run on device), 008, 011 (partial, as disclosed), 012, 016, 019, 020, 025.
**Overstated:** ATK-005 (authentication only, not authorization: open registration + OTP to your own mailbox gives full M1 access); ATK-013 (`/auth/login` timing oracle: OTP-only account returns in ~0 ms vs ~213 ms for unknown email; dev OTP also reveals existence). ATK-009 (public `/uploads`) accurate as DEFERRED but its effect is understated in combination with open registration.
Owner-action list: complete and accurate (incl. the heads-up that the local `.env` `BACKEND_CORS_ORIGINS=*` makes a production start fail on that machine; local dev with `APP_ENV` unset works).

## 7. Scope creep / blast radius
| Change | Judgement |
|---|---|
| Demo seeding gated by `SEED_DEMO_DATA` | OK (dev unchanged) |
| MockYOLO gating | NEEDS-OWNER-ATTENTION: production video processing fails until real weights are mounted (Docker image excludes `models/`) |
| New hash format (600k iterations), sessions invalidated, TTL 30→7 days | NEEDS-OWNER-ATTENTION: everyone logs in again; legacy password hashes still verify |
| Schema tightening, password minimum 6→8 | OK (compatible with the app) |
| Scripts refuse non-SQLite/production without override | OK (local PostgreSQL users hit the guard) |
| PDF reports embed frames (up to 40) | OK (size/time change) |
| Android: HTTPS-only release, `allowBackup=false`, label "Road Inspection" | NEEDS-OWNER-ATTENTION |
| `nginx.conf` WS regex, `DEPLOYMENT.md`, `run_stable_tunnel.py` (arg list, pinned localtunnel, `accept-new`) | OK (tunnel script not run) |
| `UserPublic` visible to every signed-in user | OK, but note everyone can self-register (issue 1) |

## 8. Issues to fix before committing (severity order)
1. **HIGH — open self-registration defeats the auth fix** (`routes/auth.py:80` register; legacy routers carry only the authentication dependency). Reproduced in production mode: register -> request OTP -> verify OTP -> token works on videos, distress, reports (incl. DELETE), maintenance, users, detection, GIS, `POST /live/stop`. *Fix:* registration admin-only / off in production unless `ALLOW_SELF_REGISTRATION=true`; update allow-list + tests; correct ATK-005/014 wording.
2. **MEDIUM — per-IP buckets behind a proxy** (`rate_limit.py` `client_ip`). With `TRUSTED_PROXY_COUNT=0` all users share one IP; 60 OTP requests/10 min or 100 failed verifies/15 min locks everyone out. *Fix:* production warning/refusal, set `TRUSTED_PROXY_COUNT=1` in compose, tests for `client_ip`.
3. **MEDIUM — fail-open `APP_ENV`** (`config.py`). `prd`, `staging`, `live`, empty fall back to development (dev OTP, open CORS, demo seed, mock model). *Fix:* fail closed; refuse dev OTP when platform markers (Railway etc.) are present.
4. **MEDIUM — unbounded failure counters** (`FailureLockout._failures`): memory grows without limit; failures counted for any submitted email string. *Fix:* sweep/cap; count per-email failures only for existing accounts.
5. **LOW — `/auth/login` timing oracle.** *Fix:* equivalent PBKDF2 work on every branch.
6. **LOW — demo admin in an existing production DB** (`bootstrap.py`): only a warning is logged; OTP for `admin@roaddistress.org` goes to a domain the owner may not control. *OWNER DECISION* (consider disabling OTP login for that address in production unless it equals `BOOTSTRAP_ADMIN_EMAIL`).
7. **LOW — minor tightening:** fatal startup errors in production; reject `null` CORS origin; reject trivially repetitive signing secrets; trim public `/health`.

### Owner decisions
Registration policy (closed / invite-only / admin-only); per-user or per-project scoping for the legacy M1 data (currently any signed-in user sees shared data); Railway production env (`APP_ENV`, SMTP, signing secret, `TRUSTED_PROXY_COUNT=1`, `BOOTSTRAP_ADMIN_EMAIL`, set together in one deploy); remove `CORS=*` from the local `.env` or accept a failing production start on that machine; mount model weights or set `ALLOW_MOCK_MODEL`; Android HTTPS-only release, keystore and `applicationId`; temporary-lockout trade-off (a stranger can lock a victim's email for 15 minutes); signed URLs for `/uploads`; rotating default credentials, deleting the legacy React app and `cloudflared.exe`; the CI workflow; `flutter_secure_storage`.

## 9. Unverified
No Docker, Android or CI build was run; Dart code was type-checked but not run on a device or against a live server; the 3 Dart test failures were judged by reading, with no baseline run.
