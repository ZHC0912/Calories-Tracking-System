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

# How many search hits to weigh before picking. USDA's #1 result is often a poor
# keyword match (a "bun" for "hamburger"), so we look at a few and choose the one
# whose description best overlaps the query.
_SEARCH_PAGE_SIZE = 5

# Connective words ignored when scoring description overlap.
_STOPWORDS = frozenset(
    {"with", "and", "on", "the", "of", "in", "a", "an", "or", "to", "for"}
)


def _tokens(text: str) -> set[str]:
    """Lowercase alphanumeric word set, minus connective stopwords."""
    words = "".join(c if c.isalnum() else " " for c in text.lower()).split()
    return {w for w in words if w not in _STOPWORDS}


def _extract_nutrients(food: dict) -> dict:
    """Pull our four per-100g nutrient fields out of a USDA food record."""
    result: dict = dict(EMPTY_NUTRIENTS)
    for nutrient in food.get("foodNutrients", []):
        field = _NUTRIENT_IDS.get(nutrient.get("nutrientId"))
        if field is not None and nutrient.get("value") is not None:
            result[field] = float(nutrient["value"])
    return result


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
                    "pageSize": _SEARCH_PAGE_SIZE,
                },
                timeout=10,
            )
            response.raise_for_status()
            foods = response.json().get("foods") or []
        except (requests.RequestException, ValueError, KeyError):
            return None

        food = self._pick_food(query, foods)
        if food is None:
            return None
        result = _extract_nutrients(food)
        if result["kcal"] is None:
            return None  # a match with no energy data is no better than no match
        result["fdc_id"] = food.get("fdcId")
        result["description"] = food.get("description")
        return result

    @staticmethod
    def _pick_food(query: str, foods: list[dict]) -> dict | None:
        """Choose the search hit whose description best matches the query.

        USDA ranks by keyword relevance, which often floats a partial match to
        the top (a 'bun' for 'hamburger'). Among hits that have energy data, take
        the one sharing the most words with the query, breaking ties by USDA rank.
        """
        best: dict | None = None
        best_key = (-1, 0)
        q_tokens = _tokens(query)
        for rank, food in enumerate(foods):
            if _extract_nutrients(food)["kcal"] is None:
                continue
            overlap = len(q_tokens & _tokens(food.get("description", "")))
            key = (overlap, -rank)
            if key > best_key:
                best, best_key = food, key
        return best

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
