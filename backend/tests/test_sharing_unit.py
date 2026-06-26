"""Unit tests for the share snapshot — the privacy/minimum-share rule.

build_snapshot is the gate that decides what leaves a user's account. Body-
derived parts (target, remaining) must be absent unless explicitly included.
"""

from datetime import date, datetime

from app.schemas.log import FoodEntryRead
from app.schemas.report import DailyReport
from app.schemas.social import ShareParts
from app.services.sharing import build_snapshot


def _report() -> DailyReport:
    meal = FoodEntryRead(
        id=1,
        dish="nasi lemak",
        grams=300.0,
        gram_source="estimate",
        kcal=600.0,
        protein=12.0,
        fat=24.0,
        carbs=84.0,
        image_path="meals/abc.jpg",
        eaten_at=datetime(2026, 6, 14, 8, 0),
    )
    return DailyReport(
        date=date(2026, 6, 14),
        timezone="UTC",
        total_intake_kcal=600.0,
        total_burned_kcal=140.0,
        net_kcal=460.0,
        target_kcal=2759.0,
        remaining_kcal=2299.0,
        total_protein=12.0,
        total_fat=24.0,
        total_carbs=84.0,
        meals=[meal],
        exercises=[],
        note="Estimates only — not medical advice.",
    )


def test_defaults_exclude_body_derived_parts():
    snap = build_snapshot(_report(), ShareParts())  # all defaults
    # Consistency signals always present.
    assert snap["logged"] is True
    assert snap["meals_count"] == 1
    # Net calories on by default; macros/images/target off.
    assert "net_kcal" in snap
    assert "total_protein" not in snap
    assert "food_images" not in snap
    # Body-derived must NOT leak by default.
    assert "target_kcal" not in snap
    assert "remaining_kcal" not in snap


def test_target_included_only_when_explicit():
    snap = build_snapshot(_report(), ShareParts(include_target=True))
    assert snap["target_kcal"] == 2759.0
    assert snap["remaining_kcal"] == 2299.0


def test_macros_and_images_opt_in():
    parts = ShareParts(include_macros=True, include_food_images=True)
    snap = build_snapshot(_report(), parts)
    assert snap["total_protein"] == 12.0
    assert snap["food_images"] == [{"dish": "nasi lemak", "image_path": "meals/abc.jpg"}]


def test_snapshot_never_contains_profile_stats():
    snap = build_snapshot(_report(), ShareParts(include_target=True, include_macros=True))
    for forbidden in ("weight", "height", "age", "bmi", "sex"):
        assert forbidden not in snap
