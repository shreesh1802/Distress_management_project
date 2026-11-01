"""
Measure the backend's real memory use while it runs live detection fed by a
phone-style camera stream (the app's "This device's camera" path).

What it does (all local, nothing is sent anywhere):
  1. Starts the FastAPI server in a child process on a private port with a
     temporary SQLite database (your real database is not touched).
  2. Logs in with the development one-time code, opens the authenticated
     /live/phone-stream WebSocket, and sends one JPEG frame every 0.4 s --
     exactly what the Flutter app does -- for --duration seconds.
  3. Samples the server process memory every 0.5 s (RSS = RAM in use, USS =
     memory private to the process) and prints a live table, then a summary
     with a verdict for common hosting plans.

Run from the backend folder:
    .venv\\Scripts\\python.exe scripts\\memory_profile_live.py
    .venv\\Scripts\\python.exe scripts\\memory_profile_live.py --duration 90 --csv mem.csv

Numbers are from the machine you run it on. A Linux container differs a little
(usually somewhat lower), so treat the plan verdicts as a close estimate and
confirm with the host's own memory graph.
"""

import argparse
import asyncio
import csv
import json
import os
import statistics
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

import cv2
import numpy as np
import psutil
import websockets

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MB = 1024 * 1024
PLANS_MB = [256, 512, 1024, 2048]


def road_like_jpeg(width=640, height=480):
    """A synthetic road scene: asphalt texture, lane markings, a dark crack."""
    rng = np.random.default_rng(7)
    img = np.full((height, width, 3), 95, np.uint8)
    img = np.clip(img + rng.normal(0, 14, img.shape), 0, 255).astype(np.uint8)
    cv2.line(img, (width // 2, height), (width // 2 - 40, height // 3), (230, 230, 230), 8)
    cv2.line(img, (60, height), (200, height // 3), (230, 230, 230), 5)
    cv2.polylines(img, [np.array([[220, 300], [260, 340], [250, 380], [300, 420]])], False, (20, 20, 20), 3)
    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 80])
    return buf.tobytes()


def api(base, method, path, token=None, body=None, timeout=60):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(f"{base}/api/v1{path}", data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read() or b"{}")


def proc_mem(proc):
    """RSS and USS (MB) of the server process plus any children."""
    procs = [proc] + proc.children(recursive=True)
    rss = uss = 0
    for p in procs:
        try:
            info = p.memory_full_info()
            rss += info.rss
            uss += getattr(info, "uss", info.rss)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    return rss / MB, uss / MB


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--duration", type=int, default=60, help="seconds of live streaming to measure (default 60)")
    ap.add_argument("--interval", type=float, default=0.4, help="seconds between frames (app default 0.4)")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--csv", default=None, help="optional path to save the samples as CSV")
    args = ap.parse_args()

    tmpdir = tempfile.mkdtemp(prefix="memprofile_")
    env = dict(os.environ)
    env.update({
        "DATABASE_URL": f"sqlite:///{os.path.join(tmpdir, 'profile.db').replace(os.sep, '/')}",
        "APP_ENV": "development",
        "PYTHONDONTWRITEBYTECODE": "1",
        "TRANSCRIPTION_ENABLED": "false",  # measure live detection only
    })
    base = f"http://127.0.0.1:{args.port}"

    print(f"Starting server on port {args.port} (temporary database, real database untouched)...")
    server = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", str(args.port)],
        cwd=BACKEND_DIR, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    proc = psutil.Process(server.pid)
    samples = []          # (t, stage, rss, uss)
    stage = {"name": "startup"}
    stop_flag = threading.Event()
    t0 = time.time()

    def sampler():
        while not stop_flag.is_set():
            try:
                rss, uss = proc_mem(proc)
            except psutil.NoSuchProcess:
                break
            samples.append((time.time() - t0, stage["name"], rss, uss))
            time.sleep(0.5)

    th = threading.Thread(target=sampler, daemon=True)
    th.start()

    try:
        # wait for the server
        for _ in range(120):
            try:
                urllib.request.urlopen(f"{base}/health", timeout=2).read()
                break
            except Exception:
                time.sleep(1)
        else:
            sys.exit("Server did not start in time.")
        time.sleep(3)
        stage["name"] = "idle (server up, no models)"
        time.sleep(4)

        otp = api(base, "POST", "/auth/request-otp", body={"email": "admin@roaddistress.org"})["dev_otp"]
        token = api(base, "POST", "/auth/verify-otp", body={"email": "admin@roaddistress.org", "code": otp})["token"]
        jpeg = road_like_jpeg()

        async def stream():
            uri = f"ws://127.0.0.1:{args.port}/api/v1/live/phone-stream"
            async with websockets.connect(uri, max_size=None) as ws:
                await ws.send(json.dumps({"type": "auth", "token": token}))
                stage["name"] = "loading models + streaming"
                end = time.time() + args.duration
                sent = 0
                last_print = 0
                while time.time() < end:
                    await ws.send(jpeg)
                    sent += 1
                    if sent == 1:
                        await asyncio.sleep(0.2)
                    # live line once per second
                    if time.time() - last_print >= 1 and samples:
                        t, _, rss, uss = samples[-1]
                        peak = max(s[2] for s in samples)
                        print(f"  t={t:6.1f}s  {stage['name']:<28} RAM in use {rss:7.1f} MB   private {uss:7.1f} MB   peak so far {peak:7.1f} MB   frames sent {sent}")
                        last_print = time.time()
                    await asyncio.sleep(args.interval)
                stage["name"] = "stopping"
            return sent

        print(f"\nStreaming phone-style frames for {args.duration}s (one every {args.interval}s)...\n")
        sent = asyncio.run(stream())
        status = api(base, "GET", "/live/status", token)
        time.sleep(2)
        stage["name"] = "after stop"
        time.sleep(3)
    finally:
        stop_flag.set()
        th.join(timeout=2)
        try:
            for c in proc.children(recursive=True):
                c.kill()
            server.kill()
        except Exception:
            pass

    if args.csv:
        with open(args.csv, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["seconds", "stage", "ram_in_use_mb", "private_mb"])
            for t, s, r, u in samples:
                w.writerow([f"{t:.1f}", s, f"{r:.1f}", f"{u:.1f}"])
        print(f"\nSamples saved to {args.csv}")

    by_stage = {}
    for _, s, r, u in samples:
        by_stage.setdefault(s, []).append((r, u))

    peak_rss = max(s[2] for s in samples)
    peak_uss = max(s[3] for s in samples)
    idle = by_stage.get("idle (server up, no models)", [(0, 0)])
    stream_rows = by_stage.get("loading models + streaming", [(0, 0)])
    steady = stream_rows[len(stream_rows) // 2:]
    steady_rss = statistics.median(r for r, _ in steady)

    print("\n" + "=" * 78)
    print("MEMORY SUMMARY (this machine, server process incl. children)")
    print("=" * 78)
    print(f"  Idle, models not loaded:        {statistics.median(r for r, _ in idle):7.1f} MB RAM in use")
    print(f"  Live detection, steady state:   {steady_rss:7.1f} MB RAM in use  (median of 2nd half of the run)")
    print(f"  PEAK during the whole run:      {peak_rss:7.1f} MB RAM in use   /   {peak_uss:7.1f} MB private")
    print(f"  Frames sent: {sent}   Server status: frames={status.get('frames')} inferences={status.get('inferences')} error={status.get('error')}")
    print("\nWill it fit? (compares the PEAK against the plan's RAM limit)")
    for plan in PLANS_MB:
        verdict = "FITS (headroom %4.0f MB)" % (plan - peak_rss) if peak_rss < plan * 0.85 else (
            "TIGHT - likely to be killed under load" if peak_rss < plan else "DOES NOT FIT - out-of-memory kill")
        print(f"  {plan:>5} MB plan:  {verdict}")
    print("\nNote: a Linux container is usually somewhat lower than Windows; confirm with the host's memory graph.")
    print("=" * 78)


if __name__ == "__main__":
    main()
