"""Application settings, loaded from environment variables / .env.

All secrets come from the environment — never hardcode them.
See backend/.env.example for the expected variables.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    usda_api_key: str = ""
    storage_dir: str = "./uploads"
    model_backend: str = "stub"
    # Directory holding a trained model (model.tflite + class_names.json) for the
    # "tflite" backend. Empty = use the bundled default (model/versions/model_v1).
    model_dir: str = ""
    usda_cache_path: str = "./data/usda_cache.json"

    # Phase 2 — persistence and auth.
    # DATABASE_URL is a SQLAlchemy URL. Use Postgres in production
    # (postgresql+psycopg2://user:pass@host/db); defaults to a local SQLite
    # file so the app and tests can run with no database server.
    database_url: str = "sqlite:///./calories.db"
    # Secret for signing JWTs — MUST be overridden in any real deployment.
    jwt_secret: str = "dev-insecure-change-me"
    jwt_expire_min: int = 60

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
