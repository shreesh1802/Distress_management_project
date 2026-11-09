"""
Small in-process rate limiter / attempt counter.

IMPORTANT: state lives in this Python process only. With several workers or
instances every one keeps its own counters, and a restart clears them. That is
acceptable as a first line of defence (and keeps the stack free of Redis);
put a shared limiter (nginx limit_req, Cloudflare, a Redis-backed limiter)
in front for real multi-instance deployments.

Memory is bounded: every structure sweeps expired keys periodically and has a
hard cap on the number of tracked keys (the oldest keys are evicted first), so a
client that submits endless distinct keys cannot grow the process without limit.
"""

import logging
import threading
import time
from collections import deque
from typing import Deque, Dict, Optional

from app.core.config import settings

logger = logging.getLogger(__name__)

DEFAULT_MAX_KEYS = 10_000
DEFAULT_SWEEP_INTERVAL_SECONDS = 60.0


class SlidingWindowLimiter:
    """Allows at most ``limit`` events per ``window`` seconds per key."""

    def __init__(self, limit: int, window_seconds: float, max_keys: int = DEFAULT_MAX_KEYS,
                 sweep_interval: float = DEFAULT_SWEEP_INTERVAL_SECONDS):
        self.limit = limit
        self.window = window_seconds
        self.max_keys = max_keys
        self.sweep_interval = sweep_interval
        self._events: Dict[str, Deque[float]] = {}
        self._lock = threading.Lock()
        self._last_sweep = time.monotonic()

    def _prune(self, key: str, now: float) -> Deque[float]:
        q = self._events.get(key)
        if q is None:
            return deque()
        while q and q[0] <= now - self.window:
            q.popleft()
        if not q:
            self._events.pop(key, None)
            return deque()
        return q

    def _sweep(self, now: float) -> None:
        """
        Called with the lock held. The full O(n) pass over all keys runs only on the time interval; the hard cap
        is enforced in O(1) per insert by evicting the oldest key (dicts keep insertion order).
        """
        if now - self._last_sweep >= self.sweep_interval:
            self._last_sweep = now
            for key in list(self._events):
                self._prune(key, now)
        while len(self._events) > self.max_keys:
            self._events.pop(next(iter(self._events)))

    def hit(self, key: str) -> bool:
        """Records an event. Returns False (and does not record) if the key is over its limit."""
        now = time.monotonic()
        with self._lock:
            self._sweep(now)
            q = self._prune(key, now)
            if len(q) >= self.limit:
                return False
            q.append(now)
            self._events[key] = q
            return True

    def count(self, key: str) -> int:
        now = time.monotonic()
        with self._lock:
            return len(self._prune(key, now))

    def size(self) -> int:
        with self._lock:
            return len(self._events)

    def reset(self, key: Optional[str] = None) -> None:
        with self._lock:
            if key is None:
                self._events.clear()
            else:
                self._events.pop(key, None)


class FailureLockout:
    """
    Counts failures per key; after ``max_failures`` inside ``window`` seconds the
    key is locked for ``lock_seconds``. A success clears the counter. The number of
    tracked keys is capped (``max_keys``) and expired keys are swept periodically.
    """

    def __init__(self, max_failures: int, window_seconds: float, lock_seconds: float,
                 max_keys: int = DEFAULT_MAX_KEYS, sweep_interval: float = DEFAULT_SWEEP_INTERVAL_SECONDS):
        self.max_failures = max_failures
        self.window = window_seconds
        self.lock_seconds = lock_seconds
        self.max_keys = max_keys
        self.sweep_interval = sweep_interval
        self._failures: Dict[str, Deque[float]] = {}
        self._locked_until: Dict[str, float] = {}
        self._lock = threading.Lock()
        self._last_sweep = time.monotonic()

    def _evict_one(self) -> None:
        """Drops the oldest key that is NOT locked (an active lock is only evicted if nothing else is left)."""
        victim = next((k for k in self._failures if k not in self._locked_until), None)
        if victim is None:
            victim = next(iter(self._failures))
        self._failures.pop(victim, None)
        self._locked_until.pop(victim, None)

    def _sweep(self, now: float) -> None:
        """
        Called with the lock held. The full O(n) pass runs only on the time interval; the hard cap is enforced
        by evicting the oldest keys one at a time (cheap in the common case).
        """
        if now - self._last_sweep >= self.sweep_interval:
            self._last_sweep = now
            for key in [k for k, until in self._locked_until.items() if until <= now]:
                self._locked_until.pop(key, None)
                self._failures.pop(key, None)
            for key in list(self._failures):
                q = self._failures[key]
                while q and q[0] <= now - self.window:
                    q.popleft()
                if not q and key not in self._locked_until:
                    self._failures.pop(key, None)
        while len(self._failures) > self.max_keys:
            self._evict_one()
        while len(self._locked_until) > self.max_keys:
            self._locked_until.pop(next(iter(self._locked_until)))

    def is_locked(self, key: str) -> bool:
        now = time.monotonic()
        with self._lock:
            until = self._locked_until.get(key)
            if until is None:
                return False
            if until <= now:
                self._locked_until.pop(key, None)
                self._failures.pop(key, None)
                return False
            return True

    def register_failure(self, key: str) -> bool:
        """Records a failure. Returns True if this failure triggered/continues a lockout."""
        now = time.monotonic()
        with self._lock:
            self._sweep(now)
            q = self._failures.setdefault(key, deque())
            while q and q[0] <= now - self.window:
                q.popleft()
            q.append(now)
            if len(q) >= self.max_failures:
                self._locked_until[key] = now + self.lock_seconds
                return True
            return False

    def register_success(self, key: str) -> None:
        with self._lock:
            self._failures.pop(key, None)
            self._locked_until.pop(key, None)

    def size(self) -> int:
        with self._lock:
            return len(self._failures)

    def reset(self) -> None:
        with self._lock:
            self._failures.clear()
            self._locked_until.clear()


_xff_warning_logged = False

XFF_WARNING = (
    "An X-Forwarded-For header was received but TRUSTED_PROXY_COUNT is 0: this server is behind a "
    "reverse proxy, so every client appears to share the proxy's IP address and the per-IP rate limits "
    "(Google sign-in, login, register) would lock EVERYONE out together. Set TRUSTED_PROXY_COUNT=1 "
    "(the number of proxies in front of the app, e.g. 1 on Railway or behind nginx)."
)


def client_ip(request) -> str:
    """
    Best-effort client address for rate limiting. By default this is the TCP peer.
    Behind ``TRUSTED_PROXY_COUNT`` reverse proxies (Railway, nginx, Cloudflare ...)
    the entry appended by the proxy closest to the app is used: ``hops[-N]`` counting from the
    RIGHT of ``X-Forwarded-For``. Entries further left are client-supplied and can be spoofed, so
    they are never trusted. Without that setting every user behind one proxy shares one address;
    in production that situation is logged loudly (once) as soon as a forwarded header is seen.
    """
    global _xff_warning_logged
    try:
        peer = request.client.host if request.client else "unknown"
        trusted = settings.TRUSTED_PROXY_COUNT
        xff = request.headers.get("x-forwarded-for", "")
        if trusted > 0:
            hops = [h.strip() for h in xff.split(",") if h.strip()]
            if len(hops) >= trusted:
                return hops[-trusted]
        elif xff and settings.is_production and not _xff_warning_logged:
            _xff_warning_logged = True
            logger.critical(XFF_WARNING)
        return peer
    except Exception:
        return "unknown"


def reset_xff_warning() -> None:
    """Test helper: allow the one-time warning to fire again."""
    global _xff_warning_logged
    _xff_warning_logged = False
