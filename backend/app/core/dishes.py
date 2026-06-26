"""Supported dish data: dish -> USDA query + portion gram tables.

The dish catalog is DATA, loaded from ``data/dishes.json`` at import time, so it
can be edited (or grown) without touching code — adding a dish = adding one JSON
entry. This module stays pure: it reads one bundled file with the stdlib at
import (no DB, no web, no per-request I/O — the catalog is read once here).

Each dish entry:
    usda_query    -- search term sent to USDA FoodData Central (FNDDS data type).
                     Malaysian dishes rarely appear verbatim in FNDDS, so the
                     query maps to the closest prepared-dish equivalent.
    default_grams -- portion assumed when the user gives no hint.
    bucket_grams  -- grams for the small/medium/large quick-pick buckets.

NOTE: portions and USDA queries are ESTIMATES — sanity-check them, because they
drive the calorie numbers shown to users.
"""

import json
from pathlib import Path

_DISHES_PATH = Path(__file__).parent / "data" / "dishes.json"

_REQUIRED_KEYS = {"usda_query", "default_grams", "bucket_grams"}
_BUCKET_KEYS = {"small", "medium", "large"}


def _load_dishes(path: Path = _DISHES_PATH) -> dict[str, dict]:
    """Load and structurally validate the dish catalog from JSON.

    Fails loudly at import if the file is malformed, so a bad edit can't quietly
    produce wrong portions/calories.
    """
    with path.open(encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object of dishes.")
    for name, entry in data.items():
        if not isinstance(entry, dict):
            raise ValueError(f"Dish {name!r} must be a JSON object.")
        missing = _REQUIRED_KEYS - entry.keys()
        if missing:
            raise ValueError(f"Dish {name!r} is missing keys: {sorted(missing)}.")
        if set(entry["bucket_grams"]) != _BUCKET_KEYS:
            raise ValueError(
                f"Dish {name!r} bucket_grams must have exactly small/medium/large."
            )
    return data


DISHES: dict[str, dict] = _load_dishes()

# Fallback portion when a dish is not in DISHES at all.
GENERIC_DEFAULT_GRAMS = 250.0

SUPPORTED_DISHES: list[str] = list(DISHES)

# Maps the model's output labels (the malaysia-food-11 class folder names) to the
# DISHES keys above, so a predicted label resolves to a portion + USDA query. The
# real model backend looks up class_names[pred] in here. Labels use underscores
# ("nasi_lemak") while the DISHES keys use spaces ("nasi lemak"), and
# normalize_name does NOT turn "_" into a space — so this bridge is required.
LABEL_TO_DISH: dict[str, str] = {
    "nasi_lemak": "nasi lemak",
    "fish_and_chips": "fish and chips",
    "fried_noodles": "fried noodles",
    "fried_rice": "fried rice",
    "hamburger": "hamburger",
    "laksa": "laksa",
    "mixed_rice": "mixed rice",
    "popiah": "popiah",
    "roti_canai": "roti canai",
    "satay": "satay",
    "kaya_toast": "kaya toast",
}


def normalize_name(name: str) -> str:
    return " ".join(name.lower().split())


def get_dish(name: str) -> dict | None:
    """Look up a dish entry by name, case/whitespace-insensitive."""
    return DISHES.get(normalize_name(name))
