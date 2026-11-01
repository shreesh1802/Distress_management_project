# 05 — Supervisor Final Gate (Round 3)

**Role:** read-only final gate. Verified file integrity after the defender's interrupted mutation test, verified each round-2 fix against the real code, re-ran the tests and checks independently.
**Verdict:** **SAFE TO COMMIT, confidence ~88%.** Not safe to *deploy* until the owner actions in section 6 are done. One recommended pre-deploy fix (Gap A) was sent back to the defender; see `03_DEFENDER_REPORT.md` "Final fixes".
**Containment:** the supervisor wrote nothing in the repo; `git status` was identical before and after its test run. It did not open `.env` or `road_distress.db`.

## 1. File-integrity verdict: CLEAN
Background: the defender's interrupted mutation check (it deliberately re-introduces bugs to prove the tests catch them) left `deps.py`, `config.py` and `auth.py` mutated on disk until the defender noticed and restored them from backups. Its mutation script also mutated `rate_limit.py`, which was not on the disclosed list. All were read in full.

| File | Verdict | Evidence |
|---|---|---|
| `app/core/deps.py` | CLEAN | `get_current_user` raises 401 for missing/non-Bearer header, unresolved/expired token, vanished user; `require_admin` checks `user.role != Role.ADMIN`; `registration_gate` returns early only when `settings.allow_self_registration` is true. No `if True:`, no inverted comparison |
| `app/core/config.py` | CLEAN | `is_production` = `not is_development`; `DEVELOPMENT_ENV_NAMES = {"", development, dev, local, test}`; `allow_self_registration` defaults to `is_development`; production defaults for `otp_dev_mode`, `seed_demo_data`, `allow_mock_model`, `cors_origins` key off `is_production` |
| `app/api/v1/routes/auth.py` | CLEAN | login verifies against a dummy hash when the stored hash is unusable; register depends on `registration_gate` and always assigns `SELF_REGISTER_ROLE`; request-otp / verify-otp / `/me` / logout intact |
| `app/core/rate_limit.py` | CLEAN | `trusted = settings.TRUSTED_PROXY_COUNT` intact; takes `hops[-trusted]`, never the spoofable left side |
| `app/main.py` | CLEAN | router-level authentication dependency on health/details, distress, gis, reports, maintenance, videos, upload, detection, live; users/projects/audits/assets use per-route `get_current_user`/`require_admin`; report downloads use `_require_download_access`; WebSockets use first-message auth; `validate_runtime_config` runs before the app is created |
The public-route allow-list matches the report exactly: `/health`, `/api/v1/health`, `POST /auth/{login,register,request-otp,verify-otp}`, `/download-apk`, `/app-release.apk`, and the `/uploads` mount (docs only in development). The scratchpad backups `auth.bak`, `config.bak`, `deps.bak` were diffed against the live files (ignoring line endings): identical.

## 2. Residue scan: nothing found
Searched `app/`, `tests/`, `scripts/`, `mobile/lib` for: mutation/mutant, XXX, hack, FIXME, TEMP, `or True`, `if True:`, `and False`, commented-out 401/403 raises, bypass/backdoor/skip_auth, `return True` stubs in auth/permission helpers. All hits benign (e.g. `tempfile` in conftest, a place name, the `Bypass-Tunnel-Reminder` header). No `*.bak`/`*.orig`/`*.mut`/`*.rej`/`*.tmp` files in the repo; no skipped/xfail tests; no file newer than the defender report that the report omits. Leftover scratch material exists only in the scratchpad (backups, `mutate.py`, test databases), none inside the repo.

## 3. Round-2 fix verification
| Issue | Verdict | Evidence / follow-up |
|---|---|---|
| 1 Registration | OK | Anonymous 401, non-admin 403, admin 201 when the flag is off; role always `inspector`; no other path creates an account or token anonymously (OTP needs an existing user). **Gap A:** on a platform with `APP_ENV` unset, registration was still open (sent back to the defender) |
| 2 `client_ip` / proxy | OK | Right-most trusted hop; spoofed leftmost entry ignored; CRITICAL log when `TRUSTED_PROXY_COUNT=0` in production; compose sets `"1"`. Owner: set `TRUSTED_PROXY_COUNT=1` on Railway (2 if a CDN also fronts nginx) |
| 3 `APP_ENV` fail-closed | OK | `Production`, ` production `, `prd`, `staging`, `live`, `1`, `productio` all strict; platform markers refuse dev OTP; unset still means development. Marker coverage: Railway, Heroku, Cloud Run, Kubernetes (Render/Fly/Azure not covered) |
| 4 Counters | OK | Sweep every 60 s, cap 10,000 keys, locked keys evicted last; no per-email state for unknown emails; per-email lock returns the same 401 as a wrong code (per-IP stays 429); Flutter 429 handling compatible |
| 5 Login timing | OK | Every branch runs one PBKDF2; dummy hash warmed at startup; test counts hasher calls. Minor residual: legacy 100k-iteration hashes verify faster than the 600k dummy |
| 7 Tightening | OK | Startup errors fatal in production; `null` CORS origin rejected; signing secret ≥32 chars and ≥8 distinct; `/health` status-only with details at authenticated `/api/v1/health/details`; no caller of the detailed `/health` in the app, nginx, Dockerfile or compose |
| Platform heads-up | PARTIAL | Server log is clear, but request-otp still returns 200 `sent: true` by design (hides which accounts exist), so the login screen advances to code entry with no hint; only the server log says delivery failed. Owner must read Railway logs |

## 4. Independent test results
- `pytest -p no:cacheprovider tests/security`: **322 passed, 0 failed** (matches the defender's claim; hermetic: `conftest.py` pops security-relevant env vars and forces a temp SQLite DB).
- `scripts/security_check.py`: **passed** (343 files scanned; the same 5 knowingly deferred items: `com.example` applicationId, release signing with the debug key, two compose password literals, legacy React login).
- The round-2 tests are meaningful: real HTTP status checks through `TestClient`, a rotating spoofed `X-Forwarded-For` still hits 429, hasher-call counting instead of timing, fake-clock bounds for the cap/sweep, and the defender's mutations (open gate, fail-open `is_production`, no dummy hash, `trusted = 0`) each fail these tests. Weaker spots: the compose test is a string check; no test of the per-request cost of an over-cap sweep.

## 5. New risks / behaviour changes
- **Gap A (medium, conditional):** registration, `/docs`, `CORS=*`, demo seeding and the mock model stayed on when `APP_ENV` was unset on a platform — fix sent back to the defender.
- **Gap B (low):** over-cap sweep is O(n) per request once a limiter holds 10,000 keys (needs many distinct client IPs to exploit).
- **Account-existence timing (weak):** request-otp does DB writes only for real accounts and verify-otp an extra query only for real accounts; not equalised (distinct from the login timing fix).
- **Lockout trade-off:** 5 wrong codes lock an email for 15 minutes with no new code issued; the app says "Invalid or expired code. Please request a new one."
- Without SMTP nobody can log in on a platform deployment, and the UI shows no explicit error. Outside development, `POST /auth/register` needs an admin session. Unknown `APP_ENV` values need full production configuration or startup is refused. The local `.env` with `CORS=*` makes a production start fail on this machine (dev default still works). All earlier sessions are invalidated; the mock model needs real weights or `ALLOW_MOCK_MODEL`; release APKs are HTTPS-only.
- **Issue 6 still open (owner decision):** the legacy seeded admin `admin@roaddistress.org` (user id 1) may exist in a production database. Set `BOOTSTRAP_ADMIN_EMAIL` to a mailbox you control, log in as that admin, then delete or re-address user 1.

## 6. Remaining items and owner actions
| # | Item | Status |
|---|---|---|
| Recommended before deploy | Gap A (`config.py` registration/dev defaults on platforms) | sent back to the defender |
| Optional | Gap B (`rate_limit.py` sweep) | sent back (only if trivial) |
| Optional | Timing equalisation for unknown accounts; `DEPLOYMENT.md` §6 URL; report count 57→58 | docs fixed by the defender; timing accepted as residual |

Owner actions before deploying (all in one deploy): set `APP_ENV=production`, SMTP (host/port/user/password/from), `DOWNLOAD_SIGNING_SECRET` (random, ≥32 chars), an explicit `BACKEND_CORS_ORIGINS` list, `TRUSTED_PROXY_COUNT=1`, `BOOTSTRAP_ADMIN_EMAIL`; resolve Issue 6; leave `ALLOW_SELF_REGISTRATION` off; decide on per-user scoping of the legacy M1 data, the Android keystore and applicationId, signed URLs for `/uploads`, secure token storage, credential rotation, the legacy React app and `cloudflared.exe`, any git-history scrub, and the CI workflow.

## 7. Final recommendation
**SAFE TO COMMIT (~88% confidence).** Auth, registration, rate-limit, config and startup code are clean with no residue from the interrupted mutation run; 322 tests and the offline security check pass. Not safe to *deploy* until the owner actions above are done, especially `APP_ENV=production` together with SMTP.
Not verified: Docker build, a real Railway environment, a real proxy, `flutter test`, a device run.
