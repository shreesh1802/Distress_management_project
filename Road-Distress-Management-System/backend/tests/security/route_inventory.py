"""Enumerates every route of the FastAPI app, including ones registered through include_router."""

import re
from typing import List, Set, Tuple

from fastapi.routing import APIRoute, APIWebSocketRoute

HTTP_METHODS = {"GET", "POST", "PUT", "PATCH", "DELETE"}


def _walk(routes) -> List[Tuple[str, str, str]]:
    """Returns (kind, method, path) where kind is 'http', 'ws' or 'mount'."""
    found: List[Tuple[str, str, str]] = []
    for route in routes:
        # FastAPI >= 0.13x wraps included routers lazily; unwrap them when present.
        contexts = getattr(route, "effective_route_contexts", None)
        if callable(contexts):
            for ctx in contexts():
                inner = ctx.starlette_route
                if inner is not None:
                    found.extend(_walk([inner]))
                else:
                    for method in sorted((ctx.methods or set()) & HTTP_METHODS):
                        found.append(("http", method, ctx.path))
            continue
        path = getattr(route, "path", None)
        if path is None:
            continue
        if isinstance(route, (APIWebSocketRoute,)) or route.__class__.__name__ in ("WebSocketRoute", "APIWebSocketRoute"):
            found.append(("ws", "WS", path))
        elif route.__class__.__name__ == "Mount":
            found.append(("mount", "MOUNT", path))
        else:
            methods = getattr(route, "methods", None) or set()
            for method in sorted(methods & HTTP_METHODS):
                found.append(("http", method, path))
    return found


def inventory(app) -> Set[Tuple[str, str, str]]:
    items = set(_walk(app.routes))
    # Cross-check against the public OpenAPI document so a FastAPI internals change cannot
    # silently hide routes from this inventory.
    for path, ops in app.openapi()["paths"].items():
        for method in ops:
            if method.upper() in HTTP_METHODS:
                items.add(("http", method.upper(), path))
    return items


def concrete_path(path: str) -> str:
    """Replaces {param} placeholders with a plausible value."""
    return re.sub(r"\{[^}]+\}", "1", path)
