"""
Settings configuration module for the Road Distress Management System.
Uses pydantic-settings to manage environment variables.

Deployment mode
---------------
``APP_ENV`` selects the security posture:

* ``development`` (default; also ``dev``, ``local``, ``test`` or empty): behaves like the original local/demo setup --
  OTP codes are returned in the API response (``dev_otp``), CORS is open,
  demo data is seeded, the mock detector is allowed.
* ``production``: and ANY OTHER non-empty value (``prod``, ``staging``, ``live``, ``prd``, a typo ...) -
  the setting fails CLOSED, unknown names get the strict production rules. Dev OTP is never returned or
  logged, SMTP must be configured, CORS must be an explicit allow-list,
  /docs and /openapi.json are disabled, demo seeding and the mock detector
  are OFF unless explicitly re-enabled. Misconfiguration makes the process
  refuse to start (see ``app.core.startup_checks``).
"""

import os
from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict

_FALSE_WORDS = {"0", "false", "no", "off", "n", "f"}
_TRUE_WORDS = {"1", "true", "yes", "on", "y", "t"}

# The ONLY APP_ENV values (after strip + lower-case) that mean "development". Everything else,
# including typos and names such as "staging" or "live", is treated as production-like (strict).
DEVELOPMENT_ENV_NAMES = frozenset({"", "development", "dev", "local", "test"})
# The subset that is an EXPLICIT choice of development (the empty string is "not decided").
EXPLICIT_DEVELOPMENT_NAMES = frozenset({"development", "dev", "local", "test"})
RECOGNISED_PRODUCTION_NAMES = frozenset({"production", "prod"})

# Environment variables set by hosting platforms. If one is present, the dev OTP shortcut
# (login code returned in the API response) is refused unless ALLOW_DEV_OTP_ON_PLATFORM=true.
PLATFORM_MARKERS = (
    "RAILWAY_ENVIRONMENT", "RAILWAY_PROJECT_ID", "RAILWAY_SERVICE_ID",
    "DYNO", "K_SERVICE", "KUBERNETES_SERVICE_HOST",
)


def parse_flag(value: Optional[str], default: bool) -> bool:
    """Parses an env-var style boolean. Unset/empty/unrecognised -> default."""
    if value is None:
        return default
    v = str(value).strip().lower()
    if v in _FALSE_WORDS:
        return False
    if v in _TRUE_WORDS:
        return True
    return default


class Settings(BaseSettings):
    """
    Application settings class backing environment configurations.
    """
    PROJECT_NAME: str = "Road Distress Management System"
    API_V1_STR: str = "/api/v1"

    # "development" (default, or dev/local/test/empty) or anything else = production rules. See module docstring.
    # Unset/empty = development on a developer machine, but production-like when a hosting-platform marker is
    # present (see ``app_env_implicit_production``). An explicit development name always means development.
    APP_ENV: str = ""

    # CORS origins (comma separated). Unset: "*" in development, none in production.
    BACKEND_CORS_ORIGINS: Optional[str] = None

    # Database Configurations
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_USER: str = "postgres"
    # No default password: supply POSTGRES_PASSWORD (or a full DATABASE_URL) via the environment.
    POSTGRES_PASSWORD: str = ""
    POSTGRES_DB: str = "road_distress_db"
    POSTGRES_PORT: str = "5432"

    DATABASE_URL: str | None = None

    # --- OTP / e-mail delivery -------------------------------------------------
    # Unset = on in development, always off in production.
    OTP_DEV_MODE: Optional[str] = None
    SMTP_HOST: Optional[str] = None
    SMTP_PORT: int = 587
    SMTP_USER: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    SMTP_FROM: Optional[str] = None
    SMTP_STARTTLS: Optional[str] = None  # default true; port 465 uses implicit TLS

    # Unset = on in development, off otherwise. Open self-registration lets ANY mailbox owner obtain a
    # working login, so production keeps it admin-only unless the owner deliberately turns it on.
    ALLOW_SELF_REGISTRATION: Optional[str] = None
    # Explicit override: allow the dev OTP shortcut even though a hosting-platform marker is present.
    ALLOW_DEV_OTP_ON_PLATFORM: Optional[str] = None

    # --- Seeding / bootstrap ------------------------------------------------------
    # Unset = on in development, off in production.
    SEED_DEMO_DATA: Optional[str] = None
    # Production: e-mail of the first admin account created at startup if it does not exist.
    BOOTSTRAP_ADMIN_EMAIL: Optional[str] = None

    # --- AI model --------------------------------------------------------------
    # Unset = mock detector allowed in development, forbidden in production.
    ALLOW_MOCK_MODEL: Optional[str] = None

    # Number of reverse proxies in front of the app whose X-Forwarded-For hop is trusted for
    # per-IP rate limiting (0 = use the TCP peer; set 1 behind Railway/nginx/Cloudflare).
    TRUSTED_PROXY_COUNT: int = 0

    # --- Signed report download links -----------------------------------------------
    # HMAC secret for short-lived /reports/*/download links. Required in production.
    DOWNLOAD_SIGNING_SECRET: Optional[str] = None

    @property
    def sqlalchemy_database_uri(self) -> str:
        """
        Generates the SQLAlchemy database connection URI.
        """
        if self.DATABASE_URL:
            return self.DATABASE_URL
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    # ------------------------------------------------------------------ derived
    @property
    def app_env_normalized(self) -> str:
        return (self.APP_ENV or "").strip().lower()

    @property
    def app_env_implicit_production(self) -> bool:
        """APP_ENV is unset/empty but the process runs on a hosting platform: nobody chose development, so be strict."""
        return self.app_env_normalized == "" and bool(self.platform_markers)

    @property
    def is_development(self) -> bool:
        """
        True for the explicit allow-list {development, dev, local, test}, and for an empty APP_ENV on a machine
        with no hosting-platform marker (a developer's laptop). Empty APP_ENV on Railway/Heroku/Cloud Run/
        Kubernetes counts as production-like; set APP_ENV=development explicitly to opt out there.
        """
        name = self.app_env_normalized
        if name in EXPLICIT_DEVELOPMENT_NAMES:
            return True
        return name == "" and not self.platform_markers

    @property
    def is_production(self) -> bool:
        """Fail closed: anything that is not an explicit development name gets the strict rules."""
        return not self.is_development

    @property
    def app_env_unrecognised(self) -> bool:
        """True for names that are neither development nor production/prod (typos, staging, live, prd ...)."""
        return self.app_env_normalized not in DEVELOPMENT_ENV_NAMES | RECOGNISED_PRODUCTION_NAMES

    @property
    def platform_markers(self) -> List[str]:
        return [name for name in PLATFORM_MARKERS if os.environ.get(name)]

    @property
    def dev_otp_blocked_by_platform(self) -> bool:
        """A hosting-platform marker is present and nobody explicitly allowed the dev OTP shortcut there."""
        return bool(self.platform_markers) and not parse_flag(self.ALLOW_DEV_OTP_ON_PLATFORM, False)

    @property
    def otp_dev_mode(self) -> bool:
        """Dev OTP delivery (code in API response). Never in production-like modes or on hosting platforms."""
        if self.is_production or self.dev_otp_blocked_by_platform:
            return False
        # Historical semantics: dev mode unless explicitly "false".
        return parse_flag(self.OTP_DEV_MODE, True)

    @property
    def allow_self_registration(self) -> bool:
        return parse_flag(self.ALLOW_SELF_REGISTRATION, self.is_development)

    @property
    def otp_dev_mode_requested(self) -> bool:
        """What the env var asked for, ignoring the production override (used by startup checks)."""
        return parse_flag(self.OTP_DEV_MODE, False)

    @property
    def seed_demo_data(self) -> bool:
        return parse_flag(self.SEED_DEMO_DATA, not self.is_production)

    @property
    def allow_mock_model(self) -> bool:
        return parse_flag(self.ALLOW_MOCK_MODEL, not self.is_production)

    @property
    def smtp_starttls(self) -> bool:
        return parse_flag(self.SMTP_STARTTLS, True)

    @property
    def smtp_configured(self) -> bool:
        return bool((self.SMTP_HOST or "").strip() and (self.SMTP_FROM or "").strip())

    @property
    def cors_origins(self) -> List[str]:
        raw = self.BACKEND_CORS_ORIGINS
        if raw is None:
            return [] if self.is_production else ["*"]
        origins = [o.strip() for o in raw.split(",") if o.strip()]
        # "null" is the origin of sandboxed iframes / file:// pages; never allow it.
        return [o for o in origins if o.lower() != "null"]

    # Pydantic settings configuration dict
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )


settings = Settings()
