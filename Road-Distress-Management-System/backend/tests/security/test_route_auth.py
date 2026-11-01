"""
Route-authentication matrix.

Every route of the application must answer 401 without credentials unless it is listed in
PUBLIC_ROUTES below. The allow-list is itself asserted, so adding a public route is a
deliberate, reviewed act: the test fails until the new entry is added here (and justified).
"""

import pytest

from app.main import app
from tests.security.route_inventory import inventory, concrete_path

# (method, path) -> why it is public. Anything not listed here MUST reject anonymous callers.
PUBLIC_ROUTES = {
    ("GET", "/health"): "load-balancer health probe (generic output only)",
    ("GET", "/api/v1/health"): "liveness probe",
    ("POST", "/api/v1/auth/login"): "login (rate limited)",
    # Public ONLY while ALLOW_SELF_REGISTRATION is on (default: development only). Everywhere else it needs an
    # admin session; test_round2.py::test_every_route_rejects_anonymous_callers_in_locked_down_mode proves that.
    ("POST", "/api/v1/auth/register"): "self registration, development default only (non-admin role, rate limited)",
    ("POST", "/api/v1/auth/request-otp"): "login step 1 (rate limited, uniform response)",
    ("POST", "/api/v1/auth/verify-otp"): "login step 2 (attempt limited)",
    ("GET", "/download-apk"): "sideload link for the owner's APK (REMOVE before Play release)",
    ("GET", "/app-release.apk"): "alias of /download-apk (REMOVE before Play release)",
}

# Interactive docs: exist only outside production (asserted separately in test_config).
DEV_ONLY_PUBLIC = {
    ("GET", "/docs"),
    ("GET", "/docs/oauth2-redirect"),
    ("GET", "/redoc"),
    ("GET", "/api/v1/openapi.json"),
}

# Static file mounts that are knowingly public (residual risk ATK-009, documented in SECURITY.md).
PUBLIC_MOUNTS = {"/uploads"}

# Routes that accept a bearer token OR a signed link, and answer 401 to anonymous callers.
TOKEN_OR_SIGNED_LINK = {
    ("GET", "/api/v1/reports/download/{report_id}"),
    ("GET", "/api/v1/reports/excel/download/{report_id}"),
    ("GET", "/api/v1/reports/preview/{report_id}"),
}


def _http_routes():
    return sorted((m, p) for kind, m, p in inventory(app) if kind == "http")


def test_inventory_is_not_empty_and_covers_all_routers():
    paths = {p for _, p in _http_routes()}
    for expected in ("/api/v1/users/", "/api/v1/videos/", "/api/v1/reports/", "/api/v1/live/start",
                     "/api/v1/projects/", "/api/v1/audits/", "/api/v1/assets/", "/api/v1/gis/markers",
                     "/api/v1/maintenance/schedule", "/api/v1/detection/summary", "/api/v1/upload/videos",
                     "/api/v1/distress/"):
        assert expected in paths, f"route inventory is missing {expected}"
    assert len(paths) >= 40


def test_public_allow_list_has_no_stale_entries():
    present = set(_http_routes())
    stale = set(PUBLIC_ROUTES) - present
    assert not stale, f"PUBLIC_ROUTES lists routes that no longer exist: {stale}"


def test_static_mounts_are_exactly_the_reviewed_ones():
    mounts = {p for kind, _, p in inventory(app) if kind == "mount"}
    assert mounts == PUBLIC_MOUNTS, f"unexpected static mounts: {mounts ^ PUBLIC_MOUNTS}"


def test_every_non_public_route_rejects_anonymous_callers(client):
    offenders = []
    checked = 0
    for method, path in _http_routes():
        if (method, path) in PUBLIC_ROUTES or (method, path) in DEV_ONLY_PUBLIC:
            continue
        url = concrete_path(path)
        response = client.request(method, url)
        checked += 1
        if response.status_code != 401:
            offenders.append((method, path, response.status_code))
    assert checked >= 40
    assert not offenders, (
        "These routes are reachable without authentication. Either protect them or, if they are "
        f"meant to be public, add them (with a reason) to PUBLIC_ROUTES: {offenders}"
    )


def test_token_or_signed_link_routes_exist_and_are_not_public():
    present = set(_http_routes())
    assert TOKEN_OR_SIGNED_LINK <= present
    assert not (TOKEN_OR_SIGNED_LINK & set(PUBLIC_ROUTES))


def test_invalid_bearer_token_is_rejected_everywhere(client):
    bad = {"Authorization": "Bearer " + "0" * 64}
    offenders = []
    for method, path in _http_routes():
        if (method, path) in PUBLIC_ROUTES or (method, path) in DEV_ONLY_PUBLIC:
            continue
        r = client.request(method, concrete_path(path), headers=bad)
        if r.status_code != 401:
            offenders.append((method, path, r.status_code))
    assert not offenders, offenders


@pytest.mark.parametrize("header", ["Basic abc", "Bearer", "bearer ", "Token abc", ""])
def test_malformed_authorization_headers_are_401(client, header):
    r = client.get("/api/v1/auth/me", headers={"Authorization": header})
    assert r.status_code == 401


def test_public_login_flow_routes_do_not_leak_data_without_valid_input(client):
    assert client.post("/api/v1/auth/verify-otp", json={"email": "nobody@example.test", "code": "000000"}).status_code == 401
    assert client.post("/api/v1/auth/login", json={"email": "nobody@example.test", "password": "x"}).status_code == 401
