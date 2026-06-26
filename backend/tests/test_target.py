"""Pure calorie-target math: BMR/TDEE, deficit/surplus caps, and the safe floor."""

import pytest

from app.services import target as t


def test_bmi_basic():
    # 80 kg, 180 cm -> 24.7
    assert t.bmi(80, 180) == pytest.approx(24.7, abs=0.05)


def test_bmr_mifflin_male():
    # 10*80 + 6.25*180 - 5*30 + 5 = 1780
    assert t.bmr_mifflin_st_jeor(80, 180, 30, "male") == pytest.approx(1780.0)


def test_bmr_mifflin_female_offset():
    # Female offset is 161 below the male formula for the same stats.
    male = t.bmr_mifflin_st_jeor(60, 165, 25, "male")
    female = t.bmr_mifflin_st_jeor(60, 165, 25, "female")
    assert male - female == pytest.approx(166.0)  # +5 vs -161


def test_tdee_applies_activity_factor():
    assert t.tdee(1780.0, "moderate") == pytest.approx(1780.0 * 1.55)
    # Unknown level falls back to sedentary, never crashes.
    assert t.tdee(1780.0, "bogus") == pytest.approx(1780.0 * 1.2)


def test_maintain_equals_tdee():
    assert t.daily_target(2500.0, "maintain") == 2500.0


def test_lose_applies_only_a_moderate_deficit():
    # Exactly the capped moderate deficit, not an aggressive cut.
    assert t.daily_target(2500.0, "lose") == 2500.0 - t.MODERATE_DEFICIT_KCAL


def test_gain_applies_only_a_moderate_surplus():
    assert t.daily_target(2500.0, "gain") == 2500.0 + t.MODERATE_SURPLUS_KCAL


def test_target_never_drops_below_safe_floor():
    # A small TDEE on a deficit would compute under the floor -> clamp up.
    assert t.daily_target(1500.0, "lose") == t.MIN_SAFE_KCAL
    assert t.daily_target(1000.0, "maintain") == t.MIN_SAFE_KCAL


def test_floor_is_a_hard_lower_bound_across_inputs():
    for tdee_value in range(0, 4000, 137):
        for goal in ("lose", "maintain", "gain"):
            assert t.daily_target(float(tdee_value), goal) >= t.MIN_SAFE_KCAL


def test_disclaimers_present():
    assert "not medical advice" in t.NOT_MEDICAL_ADVICE.lower()
    assert "muscle" in t.BMI_CAVEAT.lower()
