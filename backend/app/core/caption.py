"""Parse a free-text meal caption into food items with optional grams.

Examples:
    "nasi lemak"                  -> [("nasi lemak", None)]
    "nasi lemak 250g"             -> [("nasi lemak", 250.0)]
    "rice 200g, chicken 150g"     -> [("rice", 200.0), ("chicken", 150.0)]
    "roti canai and teh tarik"    -> [("roti canai", None), ("teh tarik", None)]
"""

import re
from dataclasses import dataclass

# Item separators: comma, semicolon, plus, the word "and"/"with".
_ITEM_SPLIT = re.compile(r"\s*(?:,|;|\+|\band\b|\bwith\b)\s*", re.IGNORECASE)

# A quantity like "250g", "250 g", "0.3kg", "250 grams".
_GRAMS = re.compile(r"(\d+(?:\.\d+)?)\s*(kg|grams?|g)\b", re.IGNORECASE)


@dataclass
class CaptionItem:
    name: str
    grams: float | None = None


def parse_caption(text: str | None) -> list[CaptionItem]:
    """Split a caption into items, extracting an optional gram amount per item."""
    if not text or not text.strip():
        return []

    items: list[CaptionItem] = []
    for part in _ITEM_SPLIT.split(text):
        part = part.strip()
        if not part:
            continue

        grams: float | None = None
        match = _GRAMS.search(part)
        if match:
            value = float(match.group(1))
            unit = match.group(2).lower()
            grams = value * 1000.0 if unit == "kg" else value
            part = (part[: match.start()] + part[match.end() :]).strip(" .")

        name = " ".join(part.lower().split())
        if name:
            items.append(CaptionItem(name=name, grams=grams))
    return items
