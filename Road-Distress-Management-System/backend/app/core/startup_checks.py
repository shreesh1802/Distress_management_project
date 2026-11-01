"""
Fail-closed configuration validation.

``validate_runtime_config`` is called when ``app.main`` is imported (before the
server accepts a single request). In production-like modes a misconfiguration raises
``RuntimeError`` so the process exits with a clear message instead of silently running
with development defaults. Non-fatal problems are returned (and logged) as warnings.

"Production-like" means ANY ``APP_ENV`` other than the explicit development names
(development, dev, local, test, or empty) - see ``app.core.config``.
"""

import logging
from typing import List

from app.core.config import Settings, settings as _default_settings

logger = logging.getLogger(__name__)

MIN_SIGNING_SECRET_LENGTH = 32
MIN_SIGNING_SECRET_DISTINCT_CHARS = 8


def weak_signing_secret_reason(secret: str) -> str:
    """Returns why a signing secret is unacceptable, or '' if it looks fine."""
    if len(secret) < MIN_SIGNING_SECRET_LENGTH:
        return f"it must be at least {MIN_SIGNING_SECRET_LENGTH} characters long"
    if len(set(secret)) < MIN_SIGNING_SECRET_DISTINCT_CHARS:
        return (f"it uses fewer than {MIN_SIGNING_SECRET_DISTINCT_CHARS} distinct characters "
                "(a repeated character is not a secret)")
    return ""


def weak_reviewer_code_reason(code: str) -> str:
    """Returns why a reviewer code is unacceptable, or '' if it looks fine."""
    if not (len(code) == 6 and code.isdigit()):
        return "it must be exactly 6 digits (the app's code box takes 6 digits)"
    if len(set(code)) < 4:
        return "it uses fewer than 4 distinct digits"
    if code in ("123456", "654321", "012345", "123123", "121212"):
        return "it is a well-known weak code"
    return ""


def reviewer_config_errors(cfg: Settings) -> List[str]:
    """REVIEWER_EMAIL / REVIEWER_CODE must be set together, be sane, and never name an administrator address."""
    email, code = cfg.reviewer_email, (cfg.REVIEWER_CODE or "").strip()
    if not email and not code:
        return []
    if not email or not code:
        return ["REVIEWER_EMAIL and REVIEWER_CODE must be set together (or both left unset to switch reviewer access off)."]
    errors: List[str] = []
    if "@" not in email:
        errors.append("REVIEWER_EMAIL is not an e-mail address.")
    reason = weak_reviewer_code_reason(code)
    if reason:
        errors.append(f"REVIEWER_CODE is unacceptable: {reason}.")
    admin = (cfg.BOOTSTRAP_ADMIN_EMAIL or "").strip().lower()
    if email == admin or email == "admin@roaddistress.org":
        errors.append("REVIEWER_EMAIL must not be an administrator address (reviewer accounts are always non-admin).")
    return errors


def collect_config_errors(cfg: Settings) -> List[str]:
    """Returns human-readable problems that make the configuration unsafe for production."""
    errors: List[str] = []
    if not cfg.is_production:
        return errors

    if cfg.otp_dev_mode_requested:
        errors.append(
            "OTP_DEV_MODE is enabled but this is not a development environment. Dev OTP delivery (code in the "
            "API response) is not allowed outside development; unset OTP_DEV_MODE or set it to false."
        )

    if not cfg.smtp_configured:
        errors.append(
            "SMTP is not configured. Set SMTP_HOST and SMTP_FROM (and SMTP_USER/SMTP_PASSWORD, "
            "SMTP_PORT, SMTP_STARTTLS as your provider requires) so login codes can be e-mailed."
        )
    elif bool(cfg.SMTP_USER) != bool(cfg.SMTP_PASSWORD):
        errors.append("SMTP_USER and SMTP_PASSWORD must be set together (or both left empty).")

    raw_cors = cfg.BACKEND_CORS_ORIGINS
    if raw_cors is not None:
        origins = [o.strip().lower() for o in raw_cors.split(",")]
        if "*" in origins:
            errors.append(
                "BACKEND_CORS_ORIGINS contains '*' which is not allowed in production. List the exact web origins "
                "(comma separated) or leave it unset for no cross-origin access "
                "(native Android/iOS apps and a same-origin web build do not need CORS)."
            )
        if "null" in origins:
            errors.append("BACKEND_CORS_ORIGINS contains 'null' (sandboxed iframes / file:// pages), which is not allowed.")

    errors.extend(reviewer_config_errors(cfg))

    secret = cfg.DOWNLOAD_SIGNING_SECRET or ""
    reason = weak_signing_secret_reason(secret) if secret else "it is not set"
    if reason:
        errors.append(
            f"DOWNLOAD_SIGNING_SECRET is unacceptable: {reason}. Set a random string "
            "(used to sign short-lived report download links), e.g. python -c \"import secrets; print(secrets.token_urlsafe(48))\"."
        )

    return errors


def collect_config_warnings(cfg: Settings) -> List[str]:
    """Non-fatal but important findings; shown in the start-up log (and returned for tests/tools)."""
    warnings: List[str] = []
    if cfg.app_env_implicit_production:
        warnings.append(
            "APP_ENV is not set but hosting-platform markers are present (" + ", ".join(cfg.platform_markers) + "): "
            "treating this as a PRODUCTION-like environment (strict rules: no dev OTP, no open registration, no /docs, "
            "no demo data, no mock model, explicit CORS). Set APP_ENV=production, or APP_ENV=development to choose "
            "development deliberately."
        )
    if cfg.app_env_unrecognised:
        warnings.append(
            f"APP_ENV={cfg.APP_ENV!r} is not a recognised environment name. Unknown names fail closed: the STRICT "
            "production rules apply (no dev OTP, no wildcard CORS, no demo data, no mock model, SMTP required). "
            "Use 'production' for deployments and 'development' (or leave it unset) for local work."
        )
    if cfg.is_production:
        if cfg.TRUSTED_PROXY_COUNT == 0:
            warnings.append(
                "TRUSTED_PROXY_COUNT is 0. Behind Railway, nginx or any other reverse proxy every user then shares the "
                "proxy's IP address, so the per-IP rate limits (OTP requests/attempts, login, register) can lock "
                "everyone out at once. Set TRUSTED_PROXY_COUNT=1 when exactly one proxy sits in front of the app "
                "(the app also logs a CRITICAL message as soon as it sees an X-Forwarded-For header in this state)."
            )
        if cfg.allow_self_registration:
            warnings.append(
                "ALLOW_SELF_REGISTRATION is enabled in a production-like environment: anyone can create an account, "
                "obtain a login code at their own mailbox and then use every signed-in feature. Leave it off unless "
                "you really want public sign-up."
            )
    markers = cfg.platform_markers
    if markers and not cfg.is_production:
        if cfg.dev_otp_blocked_by_platform:
            warnings.append(
                "Hosting-platform markers are present (" + ", ".join(markers) + ") while APP_ENV is a development value: "
                "the dev OTP shortcut is DISABLED. " + (
                    "Login codes will be e-mailed." if cfg.smtp_configured else
                    "SMTP is not configured, so nobody can log in. Configure SMTP_HOST/SMTP_FROM and set APP_ENV=production."
                ) + " (Override for a throw-away demo only: ALLOW_DEV_OTP_ON_PLATFORM=true.)"
            )
        elif cfg.otp_dev_mode:
            warnings.append(
                "ALLOW_DEV_OTP_ON_PLATFORM=true on a hosting platform (" + ", ".join(markers) + "): the login code is "
                "returned in API responses, so anyone who knows an account e-mail can log in as that account."
            )
    if not cfg.is_production and not markers:
        warnings.append(
            f"APP_ENV={cfg.APP_ENV!r}: running with DEVELOPMENT security defaults (dev OTP returned in API "
            "responses, open CORS, open self-registration, demo seeding). Set APP_ENV=production for any internet-facing deployment."
        )
    return warnings


def validate_runtime_config(cfg: Settings = _default_settings) -> List[str]:
    """Raises RuntimeError listing every production misconfiguration; logs and returns the warnings."""
    errors = collect_config_errors(cfg)
    warnings = collect_config_warnings(cfg)
    if errors:
        note = ""
        if cfg.app_env_implicit_production:
            note = ("\n  (APP_ENV is unset on a hosting platform, so the strict production rules apply. "
                    "Set APP_ENV=production and the settings above, or APP_ENV=development to opt out deliberately.)")
        elif cfg.app_env_unrecognised:
            note = (f"\n  (APP_ENV={cfg.APP_ENV!r} is not a recognised development name, so the strict production "
                    "rules apply. Use APP_ENV=development for local work.)")
        message = "Refusing to start: insecure production configuration:\n  - " + "\n  - ".join(errors) + note
        logger.critical(message)
        raise RuntimeError(message)

    for warning in warnings:
        logger.warning("STARTUP CHECK: %s", warning)
    return warnings
