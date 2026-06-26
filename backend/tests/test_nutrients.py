"""Nutrient scaling math and offline (cache-only) lookups. No network."""

import json

from app.core.dishes import DISHES
from app.core.nutrients import NutrientLookup, scale_nutrients

NASI_LEMAK_PER_100G = {"kcal": 230.0, "protein": 4.5, "fat": 12.0, "carbs": 26.0}


def make_lookup(tmp_path, cache: dict, api_key: str = "") -> NutrientLookup:
    cache_file = tmp_path / "usda_cache.json"
    cache_file.write_text(json.dumps(cache), encoding="utf-8")
    return NutrientLookup(api_key=api_key, cache_path=cache_file)


def test_scaling_is_grams_over_100():
    scaled = scale_nutrients(NASI_LEMAK_PER_100G, 250)
    assert scaled["kcal"] == 575.0
    assert scaled["protein"] == 11.2  # 2.5 * 4.5 rounded to 1 dp
    assert scaled["fat"] == 30.0
    assert scaled["carbs"] == 65.0


def test_scaling_preserves_none():
    scaled = scale_nutrients({"kcal": 100.0, "protein": None}, 200)
    assert scaled["kcal"] == 200.0
    assert scaled["protein"] is None
    assert scaled["fat"] is None  # absent field treated as missing, not 0


def test_lookup_serves_from_cache_without_api_key(tmp_path):
    query = DISHES["nasi lemak"]["usda_query"]
    lookup = make_lookup(tmp_path, {query: NASI_LEMAK_PER_100G})
    assert lookup.per_100g("nasi lemak") == NASI_LEMAK_PER_100G
    # Case-insensitive dish name resolves to the same cached query.
    assert lookup.per_100g("Nasi Lemak") == NASI_LEMAK_PER_100G


def test_lookup_returns_none_when_uncached_and_no_key(tmp_path):
    lookup = make_lookup(tmp_path, {})
    assert lookup.per_100g("nasi lemak") is None


def test_lookup_never_calls_network_without_key(tmp_path, monkeypatch):
    def boom(*args, **kwargs):
        raise AssertionError("network call attempted")

    monkeypatch.setattr("app.core.nutrients.requests.get", boom)
    lookup = make_lookup(tmp_path, {})
    assert lookup.per_100g("roti canai") is None


def test_missing_cache_file_is_treated_as_empty(tmp_path):
    lookup = NutrientLookup(api_key="", cache_path=tmp_path / "does_not_exist.json")
    assert lookup.per_100g("chicken rice") is None


def test_pick_food_prefers_description_overlap():
    # USDA often ranks a partial match (the bun) first; we should pick the food
    # whose description shares more words with the query.
    foods = [
        {"description": "Roll, white, hamburger bun",
         "foodNutrients": [{"nutrientId": 1008, "value": 280}]},
        {"description": "Hamburger, one patty plain",
         "foodNutrients": [{"nutrientId": 1008, "value": 250}]},
    ]
    pick = NutrientLookup._pick_food("hamburger one patty plain", foods)
    assert pick["description"] == "Hamburger, one patty plain"


def test_pick_food_skips_entries_without_energy():
    foods = [
        {"description": "exact match", "foodNutrients": []},  # no kcal -> skip
        {"description": "has energy", "foodNutrients": [{"nutrientId": 1008, "value": 100}]},
    ]
    pick = NutrientLookup._pick_food("exact match", foods)
    assert pick["description"] == "has energy"
