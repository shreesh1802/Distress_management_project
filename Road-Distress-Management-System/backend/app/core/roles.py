"""
Role constants and validation for the Road Distress Management System.

Roles are stored as free text in ``users.role`` (no schema change), but every
*write* path validates against this allow-list so a client can never invent a
role. Only ``admin`` has elevated rights (see ``app.core.deps.require_admin``).
"""

from typing import Literal, Tuple


class Role:
    ADMIN = "admin"
    INSPECTOR = "inspector"
    EMPLOYEE = "employee"
    MAINTENANCE = "maintenance"


ALL_ROLES: Tuple[str, ...] = (Role.ADMIN, Role.INSPECTOR, Role.EMPLOYEE, Role.MAINTENANCE)

# Role given to accounts created through the public /auth/register route.
# Never admin; a client-supplied role is ignored.
SELF_REGISTER_ROLE = Role.INSPECTOR

# Pydantic-friendly alias (kept in sync with ALL_ROLES; asserted in tests).
RoleName = Literal["admin", "inspector", "employee", "maintenance"]
