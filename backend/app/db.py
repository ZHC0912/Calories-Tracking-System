"""SQLAlchemy engine, session factory, and the declarative Base.

Connection string comes from config (DATABASE_URL). Postgres in production;
defaults to a local SQLite file so everything runs with no DB server. Column
types in models/ stay portable so the same schema works on both.

The API layer depends on get_db() for a request-scoped session; nothing else
opens its own connection.
"""

from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import get_settings

_settings = get_settings()

# SQLite needs check_same_thread off to be shared across FastAPI's threadpool.
_connect_args = (
    {"check_same_thread": False}
    if _settings.database_url.startswith("sqlite")
    else {}
)

engine = create_engine(_settings.database_url, connect_args=_connect_args, future=True)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)


class Base(DeclarativeBase):
    """Declarative base shared by every ORM model and Alembic's metadata."""


def get_db() -> Iterator[Session]:
    """FastAPI dependency: yields a session and always closes it."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
