"""Calorie-target math: BMI, Mifflin-St Jeor BMR -> TDEE -> a SAFE daily target.

Pure functions only — no DB, no web, no I/O — so they unit-test in isolation and
can be reused by any client. Metric units throughout (kg, cm). Every number
these return is an ESTIMATE, never medical advice (see NOT_MEDICAL_ADVICE).
"""

# --- Disclaimers (single source of truth, reused by schemas/api) -------------

NOT_MEDICAL_ADVICE = "Estimates only — not medical advice."
BMI_CAVEAT = (
    "BMI is a rough screen and does not distinguish muscle from fat, so it can "
    "mislabel muscular or older bodies."
)
ACTIVITY_GUIDANCE = (
    "General guidance: most adults benefit from about 150 minutes of moderate "
    "activity a week, spread across several days. This is general information, "
    "not a personalized plan."
)

# --- Constants ---------------------------------------------------------------

# Standard activity multipliers applied to BMR to get TDEE.
ACTIVITY_FACTORS: dict[str, float] = {
    "sedentary": 1.2,
    "light": 1.375,
    "moderate": 1.55,
    "active": 1.725,
    "very_active": 1.9,
}

# Moderate, sustainable daily adjustments (~0.25–0.5 kg/week). Deliberately
# conservative: no aggressive cuts or bulks.
MODERATE_DEFICIT_KCAL = 500.0
MODERATE_SURPLUS_KCAL = 300.0

# Absolute safe floor. The target is NEVER returned below this, whatever the
# math says — clamping here is the non-negotiable safety guard.
MIN_SAFE_KCAL = 1200.0


def bmi(weight_kg: float, height_cm: float) -> float:
    """Body Mass Index = kg / m². Rough screen only (see BMI_CAVEAT)."""
    height_m = height_cm / 100.0
    return round(weight_kg / (height_m * height_m), 1)


def bmr_mifflin_st_jeor(weight_kg: float, height_cm: float, age: int, sex: str) -> float:
    """Resting energy (kcal/day) via Mifflin-St Jeor.

    male:   10*kg + 6.25*cm - 5*age + 5
    female: 10*kg + 6.25*cm - 5*age - 161
    """
    base = 10.0 * weight_kg + 6.25 * height_cm - 5.0 * age
    offset = 5.0 if sex.lower() == "male" else -161.0
    return round(base + offset, 1)


def tdee(bmr: float, activity_level: str) -> float:
    """Total Daily Energy Expenditure = BMR * activity factor."""
    factor = ACTIVITY_FACTORS.get(activity_level, ACTIVITY_FACTORS["sedentary"])
    return round(bmr * factor, 1)


def daily_target(tdee_value: float, goal: str) -> float:
    """Daily calorie target for a goal, with moderate deltas and a safe floor.

    maintain -> TDEE; lose -> TDEE − moderate deficit; gain -> TDEE + moderate
    surplus. The result is clamped UP to MIN_SAFE_KCAL so it can never drop to
    an unsafe level, even for very small bodies on a deficit.
    """
    goal = (goal or "maintain").lower()
    if goal == "lose":
        target = tdee_value - MODERATE_DEFICIT_KCAL
    elif goal == "gain":
        target = tdee_value + MODERATE_SURPLUS_KCAL
    else:
        target = tdee_value
    return round(max(target, MIN_SAFE_KCAL), 1)


def clamp_target(value: float) -> float:
    """Clamp a user-entered target UP to the safe floor — the same non-negotiable
    guard daily_target() applies to the computed number."""
    return round(max(value, MIN_SAFE_KCAL), 1)


def effective_target(override: float | None, computed: float | None) -> float | None:
    """The target actually used: the user's override (clamped) if set, else the
    computed one (which may be None when the profile lacks the required stats).

    An override works even without full stats, so a user can set a target without
    entering weight/height/age/sex.
    """
    if override is not None:
        return clamp_target(override)
    return computed
