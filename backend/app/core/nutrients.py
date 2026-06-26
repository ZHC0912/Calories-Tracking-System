"""Nutrient lookup via USDA FoodData Central, with a local JSON cache.

Per-100g values (kcal, protein, fat, carbs) are fetched once per dish from the
FNDDS data type (prepared dishes) and cached in a JSON file, so runtime rarely
hits the API and tests can run fully offline from the cache alone.

Missing data is represented as None — never 0.
"""

import json
from pathlib import Path

import requests

from . import dishes

FDC_BASE_URL = "https://api.nal.usda.gov/fdc/v1"

# USDA nutrient ids -> our field names.
_NUTRIENT_IDS = {
    1008: "kcal",      # Energy (kcal)
    1003: "protein",   # Protein (g)
    1004: "fat",       # Total lipid (g)
    1005: "carbs",     # Carbohydrate, by difference (g)
}

NUTRIENT_FIELDS = ("kcal", "protein", "fat", "carbs")

EMPTY_NUTRIENTS: dict[str, float | None] = {field: None for field in NUTRIENT_FIELDS}


def scale_nutrients(per_100g: dict, grams: float) -> dict[str, float | None]:
    """Scale per-100g values to a portion. None stays None."""
    return {
        field: None if per_100g.get(field) is None
        else round(grams / 100.0 * per_100g[field], 1)
        for field in NUTRIENT_FIELDS
    }


class NutrientLookup:
    """Cached per-100g nutrient lookup for a dish name.

    With no API key (or no network) it serves from cache only and returns
    None for unknown dishes — it never raises.
    """

    def __init__(self, api_key: str = "", cache_path: str | Path = "data/usda_cache.json"):
        self.api_key = api_key
        self.cache_path = Path(cache_path)
        self._cache: dict[str, dict] = self._load_cache()

    def per_100g(self, dish_name: str) -> dict | None:
        """Per-100g nutrients for a dish, from cache then the USDA API."""
        query = self._query_for(dish_name)
        if query in self._cache:
            return self._cache[query]
        fetched = self._fetch(query)
        if fetched is not None:
            self._cache[query] = fetched
            self._save_cache()
        return fetched

    @staticmethod
    def _query_for(dish_name: str) -> str:
        entry = dishes.get_dish(dish_name)
        if entry:
            return entry["usda_query"]
        return dishes.normalize_name(dish_name)

    def _fetch(self, query: str) -> dict | None:
        if not self.api_key:
            return None
        try:
            response = requests.get(
                f"{FDC_BASE_URL}/foods/search",
                params={
                    "api_key": self.api_key,
                    "query": query,
                    "dataType": "Survey (FNDDS)",  # prepared dishes, values per 100 g
                    "pageSize": 1,
                },
                timeout=10,
            )
            response.raise_for_status()
            foods = response.json().get("foods") or []
            if not foods:
                return None
            food = foods[0]
            result: dict = dict(EMPTY_NUTRIENTS)
            for nutrient in food.get("foodNutrients", []):
                field = _NUTRIENT_IDS.get(nutrient.get("nutrientId"))
                if field is not None and nutrient.get("value") is not None:
                    result[field] = float(nutrient["value"])
            result["fdc_id"] = food.get("fdcId")
            result["description"] = food.get("description")
            return result
        except (requests.RequestException, ValueError, KeyError):
            return None

    def _load_cache(self) -> dict:
        try:
            with open(self.cache_path, encoding="utf-8") as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError):
            return {}

    def _save_cache(self) -> None:
        try:
            self.cache_path.parent.mkdir(parents=True, exist_ok=True)
            with open(self.cache_path, "w", encoding="utf-8") as f:
                json.dump(self._cache, f, indent=2)
        except OSError:
            pass  # cache is an optimization; failure to persist is not fatal
