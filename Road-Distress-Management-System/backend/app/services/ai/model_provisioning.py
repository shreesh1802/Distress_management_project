"""
Makes sure the detection weights exist on the server.

Git-LFS files are not always checked out by hosting platforms (the file is then a ~130 byte text pointer), and the
Docker image used to leave ``models/`` out entirely. At start-up, for each weight file that is missing or too small to
be real, this downloads it from ``MODEL_BASE_URL`` (HTTPS only) into ``backend/models``. It runs in a background
thread so the server starts answering requests at once; videos uploaded before it finishes fail with the usual
"model not available" status and can simply be uploaded again.

Download rules: written to a temporary file first and renamed only after a size/format check; the Bearer token
(``MODEL_DOWNLOAD_TOKEN``) goes to the configured host only and is dropped on a redirect to another host (CDNs
that serve signed URLs reject an extra Authorization header). The token is never logged.
"""

import logging
import os
import threading
import urllib.error
import urllib.parse
import urllib.request
from typing import List, Optional

from app.core.config import settings
from app.core.safe_paths import BACKEND_ROOT

logger = logging.getLogger(__name__)

WEIGHT_FILES = ("road_best.pth", "signage_best.pth")
MIN_REAL_SIZE = 1_000_000          # a Git-LFS pointer is ~130 bytes; the real files are tens of MB
DOWNLOAD_TIMEOUT_SECONDS = 60      # per socket read, not for the whole file
CHUNK = 1024 * 1024


def _models_dir() -> str:
    return os.path.join(BACKEND_ROOT, "models")


def missing_weights(models_dir: Optional[str] = None) -> List[str]:
    models_dir = models_dir or _models_dir()
    missing = []
    for name in WEIGHT_FILES:
        path = os.path.join(models_dir, name)
        if not os.path.isfile(path) or os.path.getsize(path) < MIN_REAL_SIZE:
            missing.append(name)
    return missing


class _DropAuthOnCrossHostRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new is not None and urllib.parse.urlsplit(newurl).netloc != urllib.parse.urlsplit(req.full_url).netloc:
            new.headers.pop("Authorization", None)
            new.unredirected_hdrs.pop("Authorization", None)
        return new


def _download(url: str, dest: str, token: str) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "road-inspection-server"})
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    opener = urllib.request.build_opener(_DropAuthOnCrossHostRedirect)
    tmp = dest + ".part"
    try:
        with opener.open(request, timeout=DOWNLOAD_TIMEOUT_SECONDS) as response, open(tmp, "wb") as out:
            while True:
                chunk = response.read(CHUNK)
                if not chunk:
                    break
                out.write(chunk)
        if os.path.getsize(tmp) < MIN_REAL_SIZE:
            raise ValueError("downloaded file is too small to be a model checkpoint")
        with open(tmp, "rb") as check:
            if check.read(2) != b"PK":  # torch checkpoints are zip archives
                raise ValueError("downloaded file is not a PyTorch checkpoint")
        os.replace(tmp, dest)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def ensure_models(models_dir: Optional[str] = None) -> bool:
    """Downloads whatever is missing. Returns True when every weight file is present afterwards."""
    models_dir = models_dir or _models_dir()
    missing = missing_weights(models_dir)
    if not missing:
        return True

    base = (settings.MODEL_BASE_URL or "").strip().rstrip("/")
    if not base:
        logger.error(
            "Detection weights missing or incomplete (%s) and MODEL_BASE_URL is not set: video and live "
            "detection will fail. Provide the files (see DEPLOYMENT.md, 'Model weights').", ", ".join(missing))
        return False
    if not base.lower().startswith("https://"):
        logger.error("MODEL_BASE_URL must start with https:// - refusing to download model weights over plain HTTP.")
        return False

    os.makedirs(models_dir, exist_ok=True)
    token = (settings.MODEL_DOWNLOAD_TOKEN or "").strip()
    for name in missing:
        logger.info("Downloading detection weights %s ...", name)
        try:
            _download(f"{base}/{name}", os.path.join(models_dir, name), token)
            logger.info("Detection weights %s ready.", name)
        except urllib.error.HTTPError as exc:
            logger.error("Could not download %s (HTTP %s). Check MODEL_BASE_URL and MODEL_DOWNLOAD_TOKEN.", name, exc.code)
        except Exception as exc:
            logger.error("Could not download %s (%s): %s", name, type(exc).__name__, exc)
    return not missing_weights(models_dir)


def ensure_models_in_background() -> threading.Thread:
    thread = threading.Thread(target=ensure_models, name="model-provisioning", daemon=True)
    thread.start()
    return thread
