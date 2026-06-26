"""Portion resolution: turn user hints (or nothing) into grams + an honest source tag."""

from . import dishes

_BUCKET_ALIASES = {
    "s": "small",
    "small": "small",
    "m": "medium",
    "medium": "medium",
    "l": "large",
    "large": "large",
}


def resolve_grams(
    dish: str,
    user_grams: float | None = None,
    bucket: str | None = None,
) -> tuple[float, str]:
    """Resolve the grams for one dish.

    Priority:
        1. explicit user grams              -> source "user"
        2. size bucket (S/M/L)              -> source "bucket"
        3. per-dish default (or generic)    -> source "estimate"
    """
    if user_grams is not None and user_grams > 0:
        return float(user_grams), "user"

    entry = dishes.get_dish(dish)

    if bucket:
        key = _BUCKET_ALIASES.get(bucket.strip().lower())
        if key and entry and key in entry["bucket_grams"]:
            return float(entry["bucket_grams"][key]), "bucket"

    if entry:
        return float(entry["default_grams"]), "estimate"
    return dishes.GENERIC_DEFAULT_GRAMS, "estimate"
