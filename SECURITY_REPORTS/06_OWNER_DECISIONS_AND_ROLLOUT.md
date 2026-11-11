# 06 — Owner Decisions, Real-World Implications, and Rollout Order

Status at time of writing: all hardening work is **uncommitted** (HEAD `0521a84`, 59 modified + ~20 new files). Nothing is pushed or deployed.
Open facts that change the impact of some rows: (1) does Railway auto-deploy from `main`? (2) is the GitHub repo public?

## A. Actions that wait on the owner

| Item | If you allow it | If you don't | Suggestion |
|---|---|---|---|
| **Commit and push** | Hardening lands on GitHub. If Railway auto-deploys from `main`, the live service restarts on the new code and **won't start** until the production settings below exist. | Fixes stay on your machine only. | Set the Railway variables first, or push to a branch and merge when ready. |
| **Include `SECURITY_REPORTS/` in the commit** | If the repo is public, the attacker report becomes a public map of weaknesses in whatever is still deployed. | Reports stay local. | Keep them out of a public repo, or commit them only after the fixes are live. |
| **CI security workflow** | Tests + security check run on every push; a failing check blocks the merge. | No automatic guard; regressions depend on someone remembering to run the checks. | Yes, after the first successful deploy. |
| **Scrub git history** | Old tunnel hostnames, IPs, personal emails in commit metadata are removed. Force-push; every commit hash changes; clones and forks break. | Old data stays in history (tunnel hostnames were temporary, so real exposure is small). | Skip unless the repo is/was public with sensitive metadata; anything already copied can't be recalled. |
| **Delete legacy React app and `cloudflared.exe`** | Removes dead code with hardcoded mock credentials; the 54 MB binary was never in git. | Nothing breaks; they just sit there. | Delete the React app; delete the binary if unused. |
| **Rotate default credentials** | Documented default passwords stop working anywhere they were used. Login is by emailed code, so practical impact is low. | Anyone who read the repo/docs can try those passwords on any server that still has them. | Rotate any real DB password; check deployed DBs for the old seeded accounts. |
| **Railway production settings** | Server starts in secure mode. Needs SMTP details, a 32+ char random secret, a CORS list, `TRUSTED_PROXY_COUNT=1`, a bootstrap admin email. | Service refuses to start, or login is impossible without email. | Required before deploying. |
| **Release signing key + real application ID** | App can be published. | Play rejects `com.example.mobile` and debug-signed builds. | Both effectively permanent: the application ID can't change after publishing; if the key is lost, Play App Signing is the only recovery. Back up the key. |
| **Secure token storage on device** | Token moves into the Android keystore (adds a native plugin). | A rooted or stolen phone could expose the token. | Worth doing before launch. |

## B. Policy decisions

| Decision | If chosen | Real-world effect |
|---|---|---|
| Registration closed / invite-only | Only admins create accounts. | No random sign-ups; new employees need an admin to add them. |
| Registration open (current dev default) | Anyone can register. | They get low privileges, but any logged-in user can see the shared M1 data. Not for production. |
| Per-user scoping of M1 data | Each user sees only their own videos, detections, reports. | Needs a DB change (project/owner column) and a data migration; real effort. Today everyone shares everything. |
| Retire seeded `admin@roaddistress.org` | Set your own bootstrap admin address, then delete or re-address user 1. | If that address exists in a deployed DB, its login codes go to a mailbox you may not control; whoever controls it becomes admin. Fix before going live. |
| Signed links for `/uploads` | Files need a short-lived link or login. | Closes the last public file area; some screens that load images/audio by bare URL need changes. Without it, files stay readable by anyone with the unguessable link. |

## C. Changes already in the working tree (veto-able)

| Change | Effect if kept | If vetoed |
|---|---|---|
| Everyone logged out once; 7-day sessions | One re-login; stolen tokens expire faster. | Longer sessions are slightly riskier. |
| Release Android builds HTTPS-only | Safer against interception; a test APK on `http://LAN` stops working (debug builds still allow HTTP). | Plain HTTP stays possible in releases; also hurts Play review. |
| Fail-closed startup with email required | Deployed servers can't accidentally run with dev settings. | A live deployment can be mistaken for dev mode (what the audit flagged). |
| Mock detector off in production | App never invents road defects; a deployment without model files returns errors. | Demos without weights keep working, but may show fabricated results as real. |
| Stricter passwords + form validation | Bad data rejected earlier. | Old data shapes accepted again. |
| Bigger reports (up to 40 frames) | Richer PDFs; slower to build. | Smaller, faster reports. |

## D. Rollout order (owner-approved) and status

| Step | What | Who | Status |
|---|---|---|---|
| 1 | **Railway production settings** (below) | **Owner** — requires the Railway dashboard and real SMTP credentials; the assistant has no Railway access (no CLI, no credentials) | WAITING ON OWNER |
| 2 | **Bootstrap admin**: set `BOOTSTRAP_ADMIN_EMAIL` to a mailbox you control, log in as that admin, then delete/re-address legacy user 1 (`admin@roaddistress.org`) | Owner (production DB); assistant can prepare steps | WAITING ON OWNER INPUT (admin email) |
| 3 | **Merge**: commit and push (branch first, then merge); keep `SECURITY_REPORTS/` out of the commit if the repo is public | Assistant, after steps 1–2 are confirmed and visibility/auto-deploy are known | NOT STARTED (deliberately last) |

### Owner answers recorded
- GitHub repo visibility: **private** -> `SECURITY_REPORTS/` is safe to commit.
- Railway auto-deploy from `main`: **not sure** -> push to a branch (`security-hardening`) first; merge to `main` only after the Railway variables are confirmed set.
- Step 1 (Railway variables + SMTP): **owner is setting them now**; assistant waits for the owner to confirm the deploy is up.
- Production bootstrap admin mailbox (step 2): **`road.project@thapar.edu`** -> set `BOOTSTRAP_ADMIN_EMAIL=road.project@thapar.edu`, log in as that admin (the login code is emailed there), then delete or re-address the legacy seeded user 1 (`admin@roaddistress.org`) so its codes cannot go to a mailbox you do not control.

### Railway variables to set together in one deploy (names verified against SECURITY.md)
| Variable | Value |
|---|---|
| `APP_ENV` | `production` |
| `SMTP_HOST`, `SMTP_FROM` | required (your email provider) |
| `SMTP_PORT` | optional, default 587 (465 = implicit TLS) |
| `SMTP_USER`, `SMTP_PASSWORD` | as your provider requires (set both or neither) |
| `DOWNLOAD_SIGNING_SECRET` | random, >= 32 chars with >= 8 distinct; generate yourself with `python -c "import secrets; print(secrets.token_urlsafe(48))"` (do not paste it into chat or commit it) |
| `BACKEND_CORS_ORIGINS` | exact web origins, comma separated; unset = no cross-origin access; `*` and `null` are rejected in production |
| `TRUSTED_PROXY_COUNT` | `1` on Railway (number of proxies in front of the app) |
| `BOOTSTRAP_ADMIN_EMAIL` | a mailbox you control |
| Leave unset | `OTP_DEV_MODE`, `ALLOW_SELF_REGISTRATION`, `ALLOW_DEV_OTP_ON_PLATFORM`, `SEED_DEMO_DATA`, `ALLOW_MOCK_MODEL` |
Also make sure the YOLOX model weights are available in the deployment, otherwise video processing returns errors in production (the mock detector is off).
After the deploy: `GET /health` should return `{"status":"healthy"}`, `/docs` should be 404, an anonymous `GET /api/v1/videos/` should be 401, and a login code should arrive by email (the app shows no error if delivery fails; check the Railway logs for "Cannot deliver login code").
