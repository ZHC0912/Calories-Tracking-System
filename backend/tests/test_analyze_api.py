"""End-to-end /analyze with StubBackend and a seeded cache. Fully offline."""

import io
import json

import pytest
from fastapi.testclient import TestClient

from app.config import get_settings
from app.core.dishes import DISHES
from app.main import app

PER_100G = {
    DISHES["nasi lemak"]["usda_query"]: {"kcal": 230.0, "protein": 4.5, "fat": 12.0, "carbs": 26.0},
    DISHES["chicken rice"]["usda_query"]: {"kcal": 165.0, "protein": 9.0, "fat": 5.0, "carbs": 21.0},
}


@pytest.fixture
def client(tmp_path, monkeypatch):
    cache_file = tmp_path / "usda_cache.json"
    cache_file.write_text(json.dumps(PER_100G), encoding="utf-8")
    monkeypatch.setenv("USDA_API_KEY", "")
    monkeypatch.setenv("USDA_CACHE_PATH", str(cache_file))
    monkeypatch.setenv("MODEL_BACKEND", "stub")
    get_settings.cache_clear()
    yield TestClient(app)
    get_settings.cache_clear()


def post_analyze(client, caption=None, grams=None, bucket=None, image=b"fake-image-bytes"):
    data = {}
    if caption is not None:
        data["caption"] = caption
    if grams is not None:
        data["grams"] = str(grams)
    if bucket is not None:
        data["bucket"] = bucket
    return client.post(
        "/analyze",
        files={"image": ("meal.jpg", io.BytesIO(image), "image/jpeg")},
        data=data,
    )


def test_caption_with_grams_drives_dish_and_portion(client):
    response = post_analyze(client, caption="nasi lemak 250g")
    assert response.status_code == 200
    body = response.json()
    assert len(body["items"]) == 1
    item = body["items"][0]
    assert item["dish"] == "nasi lemak"
    assert item["grams"] == 250.0
    assert item["gram_source"] == "user"
    assert item["kcal"] == 575.0  # 2.5 * 230 from seeded cache
    assert body["total_kcal"] == 575.0


def test_no_caption_returns_stub_dishes_with_estimates(client):
    response = post_analyze(client)
    assert response.status_code == 200
    body = response.json()
    assert 1 <= len(body["items"]) <= 2
    for item in body["items"]:
        assert item["dish"] in DISHES
        assert item["gram_source"] == "estimate"
        assert item["grams"] == DISHES[item["dish"]]["default_grams"]


def test_bucket_hint_applies(client):
    response = post_analyze(client, caption="chicken rice", bucket="large")
    item = response.json()["items"][0]
    assert item["gram_source"] == "bucket"
    assert item["grams"] == DISHES["chicken rice"]["bucket_grams"]["large"]


def test_uncached_dish_reports_none_not_zero(client):
    response = post_analyze(client, caption="roti canai")
    item = response.json()["items"][0]
    assert item["dish"] == "roti canai"
    assert item["kcal"] is None
    assert item["protein"] is None


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}
