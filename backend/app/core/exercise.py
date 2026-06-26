"""Exercise calorie math: MET-based computation or direct user-supplied kcal.

kcal = MET * weight_kg * hours  (standard MET formula; 1 MET ~ 1 kcal/kg/h)

Like gram_source on food items, the result is tagged with how the number was
obtained: "computed" (from METs) or "user" (entered directly).
"""

# MET values from the Compendium of Physical Activities (rounded, common cases).
MET_TABLE: dict[str, float] = {
    "walking": 3.5,
    "brisk walking": 4.3,
    "running": 9.8,
    "jogging": 7.0,
    "cycling": 7.5,
    "swimming": 8.0,
    "hiking": 6.0,
    "badminton": 5.5,
    "basketball": 6.5,
    "football": 7.0,
    "yoga": 2.5,
    "weight training": 3.5,
    "dancing": 5.0,
    "skipping rope": 11.0,
}


def calories_burned(met: float, weight_kg: float, hours: float) -> float:
    """Kilocalories burned for a given MET value, body weight (kg) and duration (h)."""
    return round(met * weight_kg * hours, 1)


def log_exercise(
    activity: str,
    weight_kg: float | None = None,
    hours: float | None = None,
    kcal: float | None = None,
) -> dict:
    """Build one exercise entry.

    Either pass `kcal` directly (source "user"), or pass `weight_kg` + `hours`
    for a known activity to compute it from METs (source "computed").
    """
    activity_key = " ".join(activity.lower().split())

    if kcal is not None:
        return {"activity": activity_key, "kcal": round(float(kcal), 1), "source": "user"}

    if weight_kg is None or hours is None:
        raise ValueError("Provide kcal directly, or weight_kg and hours to compute it.")
    met = MET_TABLE.get(activity_key)
    if met is None:
        raise ValueError(
            f"Unknown activity {activity_key!r} and no direct kcal given. "
            f"Known activities: {', '.join(sorted(MET_TABLE))}"
        )
    return {
        "activity": activity_key,
        "kcal": calories_burned(met, weight_kg, hours),
        "source": "computed",
    }
