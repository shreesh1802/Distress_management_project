"""
Database models base configuration for the Road Distress Management System.
Defines SQLAlchemy DeclarativeBase with standard index naming conventions.
"""

from datetime import datetime, timezone

from sqlalchemy import DateTime, MetaData, event
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.orm.attributes import set_committed_value

# Naming convention for SQL constraints to make database migrations clean
convention = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s"
}


class Base(DeclarativeBase):
    """
    Base class for all SQLAlchemy database models.
    Inherited tables will automatically resolve properties.
    """
    metadata = MetaData(naming_convention=convention)


def _mark_stored_times_as_utc(target, *_args) -> None:
    """
    Every timestamp column is ``DateTime(timezone=True)`` and holds UTC. PostgreSQL hands such values back
    with their time zone, but SQLite (local development, tests) drops it, so the API would send
    "2026-11-27T20:30:00" and a phone would read that as its own local time. Re-attach UTC on load so the
    API always sends "+00:00" and clients can convert to local time correctly.
    """
    for attr in target.__class__.__mapper__.column_attrs:
        column = attr.columns[0]
        if not isinstance(column.type, DateTime) or not column.type.timezone:
            continue
        value = target.__dict__.get(attr.key)
        if isinstance(value, datetime) and value.tzinfo is None:
            set_committed_value(target, attr.key, value.replace(tzinfo=timezone.utc))


event.listen(Base, "load", _mark_stored_times_as_utc, propagate=True)
event.listen(Base, "refresh", _mark_stored_times_as_utc, propagate=True)
