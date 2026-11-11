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


def collect_config_errors(cfg: Settings) -> List[str]:
    """Returns human-readable problems that make the configuration unsafe for production."""
    errors: List[str] = []
    if not cfg.is_production:
        return errors

    if not ((cfg.FIREBASE_CREDENTIALS_JSON or "").strip() or (cfg.FIREBASE_CREDENTIALS_PATH or "").strip()):
        errors.append(
            "Firebase credentials are not configured, so nobody could sign in with Google. Set "
            "FIREBASE_CREDENTIALS_JSON (the service-account JSON, for hosts such as Railway) or "
            "FIREBASE_CREDENTIALS_PATH."
        )

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
            "treating this as a PRODUCTION-like environment (strict rules: no /docs, no demo data, no mock model, "
            "explicit CORS, Firebase credentials required). Set APP_ENV=production, or APP_ENV=development to "
            "choose development deliberately."
        )
    if cfg.app_env_unrecognised:
        warnings.append(
            f"APP_ENV={cfg.APP_ENV!r} is not a recognised environment name. Unknown names fail closed: the STRICT "
            "production rules apply (no wildcard CORS, no demo data, no mock model, Firebase credentials required). "
            "Use 'production' for deployments and 'development' (or leave it unset) for local work."
        )
    if cfg.is_production and cfg.TRUSTED_PROXY_COUNT == 0:
        warnings.append(
            "TRUSTED_PROXY_COUNT is 0. Behind Railway, nginx or any other reverse proxy every user then shares the "
            "proxy's IP address, so the per-IP rate limits (Google sign-in, login, register) can lock "
            "everyone out at once. Set TRUSTED_PROXY_COUNT=1 when exactly one proxy sits in front of the app "
            "(the app also logs a CRITICAL message as soon as it sees an X-Forwarded-For header in this state)."
        )
    if not cfg.is_production and not cfg.platform_markers:
        warnings.append(
            f"APP_ENV={cfg.APP_ENV!r}: running with DEVELOPMENT security defaults (open CORS, demo seeding, mock "
            "detector allowed). Set APP_ENV=production for any internet-facing deployment."
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
