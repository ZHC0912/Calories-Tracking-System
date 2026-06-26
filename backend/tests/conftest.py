"""Shared fixtures for Phase 2 DB-backed tests.

Each test gets a fresh in-memory SQLite database (via dependency override) plus
a temp storage dir and a seeded USDA cache, so logging produces real calorie
numbers fully offline. Target-math tests need none of this and import directly.
"""

import json

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import config
from app.db import Base, get_db
from app.main import app

# Seeded per-100g nutrients keyed by the USDA query for "nasi lemak", so a
# logged nasi lemak yields deterministic calories with no network.
_SEED_CACHE = {
    "rice cooked with coconut milk": {
        "kcal": 200.0,
        "protein": 4.0,
        "fat": 8.0,
        "carbs": 28.0,
    }
}


@pytest.fixture
def client(tmp_path, monkeypatch):
    cache_path = tmp_path / "usda_cache.json"
    cache_path.write_text(json.dumps(_SEED_CACHE), encoding="utf-8")
    monkeypatch.setenv("USDA_CACHE_PATH", str(cache_path))
    monkeypatch.setenv("USDA_API_KEY", "")  # never hit the network in tests
    monkeypatch.setenv("STORAGE_DIR", str(tmp_path / "uploads"))
    config.get_settings.cache_clear()

    # One shared in-memory DB for the test's lifetime (StaticPool keeps it).
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        future=True,
    )
    Base.metadata.create_all(engine)
    TestingSession = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

    def override_get_db():
        db = TestingSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    config.get_settings.cache_clear()


def register_and_login(client, email="user@example.com", password="password123") -> str:
    """Register a user and return a bearer token."""
    resp = client.post("/auth/register", json={"email": email, "password": password})
    assert resp.status_code == 201, resp.text
    return resp.json()["access_token"]


def auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}
