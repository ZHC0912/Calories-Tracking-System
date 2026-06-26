"""Exercise math: MET formula and direct-kcal entry."""

import pytest

from app.core.exercise import MET_TABLE, calories_burned, log_exercise


def test_met_formula():
    # 3.5 MET * 70 kg * 1 h = 245 kcal
    assert calories_burned(3.5, 70, 1) == 245.0


def test_met_formula_fractional_hours():
    assert calories_burned(9.8, 60, 0.5) == 294.0


def test_computed_entry():
    entry = log_exercise("running", weight_kg=70, hours=1)
    assert entry["kcal"] == MET_TABLE["running"] * 70
    assert entry["source"] == "computed"


def test_direct_kcal_entry():
    entry = log_exercise("running", kcal=200)
    assert entry == {"activity": "running", "kcal": 200.0, "source": "user"}


def test_direct_kcal_works_for_unknown_activity():
    entry = log_exercise("kayaking", kcal=350)
    assert entry["source"] == "user"


def test_activity_name_normalized():
    entry = log_exercise("  Brisk   Walking ", weight_kg=80, hours=1)
    assert entry["activity"] == "brisk walking"


def test_unknown_activity_without_kcal_raises():
    with pytest.raises(ValueError):
        log_exercise("kayaking", weight_kg=70, hours=1)


def test_missing_inputs_raise():
    with pytest.raises(ValueError):
        log_exercise("running", weight_kg=70)  # no hours, no kcal
