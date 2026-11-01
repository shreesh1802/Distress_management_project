"""Shared pagination query parameters with an enforced upper bound (SUP-003)."""

from fastapi import Query

# Largest page any list endpoint will serve. The Flutter app asks for at most
# 1000 rows (analytics / maintenance); anything above is rejected with 422.
MAX_PAGE_LIMIT = 1000
# /users/ is only used to populate assignee dropdowns.
MAX_USER_PAGE_LIMIT = 200


def skip_param() -> int:
    return Query(0, ge=0, le=1_000_000, description="Rows to skip")


def limit_param() -> int:
    return Query(100, ge=1, le=MAX_PAGE_LIMIT, description=f"Max rows to return (<= {MAX_PAGE_LIMIT})")


def user_limit_param() -> int:
    return Query(100, ge=1, le=MAX_USER_PAGE_LIMIT, description=f"Max rows to return (<= {MAX_USER_PAGE_LIMIT})")
