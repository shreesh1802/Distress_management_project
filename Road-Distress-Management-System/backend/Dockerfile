FROM python:3.12-slim

# build-essential: pycocotools/yolox compile native extensions at install time.
# libgl1/libglib2.0-0: runtime shared libs opencv-python needs (no X server
# on a headless server, but these libs are still linked at import time).
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Unprivileged user the server runs as (see docker-entrypoint.sh, which drops root after
# fixing the ownership of the upload/report volumes).
RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --create-home --home-dir /home/app --shell /usr/sbin/nologin app

# WORKDIR is one level deeper than usual (/app/backend, not /app) on
# purpose: every path helper in this codebase computes its output directory
# as N ".." hops up from its own __file__ -- uploads/ always lands inside
# backend/, but reports/ (pdf_generator.py, excel_generator.py, and all 3
# download routes in reports.py) consistently adds one extra ".." and lands
# as a *sibling* of backend/, matching how it already behaves in local dev
# (running uvicorn from backend/ still writes to ../reports). Using /app as
# WORKDIR directly would silently resolve that sibling path to the
# container's unmounted filesystem root instead of a mounted volume.
WORKDIR /app/backend

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# yolox's own PyPI metadata pins onnx==1.8.1 (no wheel for this Python
# version) among other training-only deps this project's inference path
# never uses -- --no-deps skips that unresolvable set. See the comment in
# requirements.txt above the pycocotools/loguru/tabulate/thop/tqdm block.
RUN pip install --no-cache-dir cmake ninja \
    && pip install --no-cache-dir yolox==0.3.0 --no-deps --no-build-isolation

COPY . .

# uploads/ (raw + processed videos, detection crops) persists inside
# backend/; reports/ (generated PDF/Excel) persists one level up -- both
# mounted as volumes in docker-compose.yml, not baked into the image.
# .cache/ holds the ffmpeg copy used by audio transcription.
RUN mkdir -p uploads ../reports .cache \
    && sed -i 's/\r$//' docker-entrypoint.sh \
    && chmod 0755 docker-entrypoint.sh \
    && chown -R app:app /app /home/app

EXPOSE 8000
# Starts as root only long enough to chown the data volumes, then runs uvicorn as "app".
ENTRYPOINT ["/app/backend/docker-entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
