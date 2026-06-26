"""Pydantic schema for the computed daily report.

The report is intentionally flat (totals) + lists (meals, exercises) so Phase 3
can selectively share fragments — e.g. net-calories-only, or the food images
only — without restructuring. This is the same object Phase 3's feed will share.
"""

from datetime import date as date_type
from typing import Optional

from pydantic import BaseModel

from .log import ExerciseEntryRead, FoodEntryRead


class DailyReport(BaseModel):
    date: date_type
    timezone: str

    total_intake_kcal: float
    total_burned_kcal: float
    net_kcal: float  # intake − burned
    target_kcal: Optional[float] = None  # None until the profile is complete
    remaining_kcal: Optional[float] = None  # target − net (None if no target)

    total_protein: float
    total_fat: float
    total_carbs: float

    meals: list[FoodEntryRead]
    exercises: list[ExerciseEntryRead]

    note: str
