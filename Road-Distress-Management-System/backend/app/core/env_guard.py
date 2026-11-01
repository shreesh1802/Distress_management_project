"""
Safety guard for destructive / demo-data command-line scripts (seed_data.py,
reset_test_data.py, add_demo_detections.py, register_demo_video.py).

The scripts refuse to run when
  * APP_ENV=production, or
  * DATABASE_URL (or the POSTGRES_* settings) point at anything other than SQLite,
unless the operator deliberately sets ALLOW_DESTRUCTIVE_SCRIPTS=yes-i-know-this-wipes-data
for that one invocation.
"""

import os
import sys

from sqlalchemy.engine import make_url

from app.core.config import settings

OVERRIDE_VAR = "ALLOW_DESTRUCTIVE_SCRIPTS"
OVERRIDE_VALUE = "yes-i-know-this-wipes-data"


def check_script_environment(script_name: str) -> list:
    """Returns the list of reasons the script must not run (empty = safe to run)."""
    reasons = []
    if settings.is_production:
        reasons.append("APP_ENV is 'production'")
    try:
        backend = make_url(settings.sqlalchemy_database_uri).get_backend_name()
    except Exception:
        backend = "unknown"
    if backend != "sqlite":
        reasons.append(f"the configured database is '{backend}', not a local SQLite file")
    return reasons


def require_safe_environment(script_name: str) -> None:
    """Call first thing in a destructive script's main(); exits with status 2 if unsafe."""
    reasons = check_script_environment(script_name)
    if not reasons:
        return
    if os.environ.get(OVERRIDE_VAR) == OVERRIDE_VALUE:
        print(f"WARNING: {script_name} running against a protected environment ({'; '.join(reasons)}) "
              f"because {OVERRIDE_VAR} is set.", file=sys.stderr)
        return
    print(
        f"REFUSING to run {script_name}: " + "; ".join(reasons) + ".\n"
        f"This script deletes or fabricates data. If you really mean it, run it once with "
        f"{OVERRIDE_VAR}={OVERRIDE_VALUE}",
        file=sys.stderr,
    )
    sys.exit(2)
