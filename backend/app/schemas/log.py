"""Pydantic schemas for logging meals and exercise, plus their read shapes.

A LogFoodItem is a CONFIRMED item: the user has already seen the /analyze
result and may have corrected the dish or entered grams. The server re-resolves
grams and re-looks-up nutrients (Phase 1 logic) before persisting, so a thin or
malicious client can't inject arbitrary calorie numbers.
"""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field, model_validator

from .analysis import GramSource


class LogFoodItem(BaseModel):
    """One confirmed food item to log.

    grams (explicit) wins over bucket; if neither is given the Phase 1 portion
    estimate for the dish is used.
    """

    dish: str
    grams: Optional[float] = Field(default=None, gt=0)
    bucket: Optional[str] = None  # small/medium/large (or s/m/l)


class LogFoodRequest(BaseModel):
    """Body for POST /log/food. (An optional image is sent as a separate file.)"""

    items: list[LogFoodItem] = Field(min_length=1)


class LogExerciseRequest(BaseModel):
    """Body for POST /log/exercise.

    Either give `kcal` directly (source 'user'), or `activity` + `minutes` to
    compute it from METs using the user's body weight (source 'computed').
    """

    activity: str
    minutes: Optional[float] = Field(default=None, gt=0)
    kcal: Optional[float] = Field(default=None, gt=0)

    @model_validator(mode="after")
    def _need_minutes_or_kcal(self) -> "LogExerciseRequest":
        if self.minutes is None and self.kcal is None:
            raise ValueError("Provide either minutes (to compute) or kcal directly.")
        return self


class FoodEntryRead(BaseModel):
    id: int
    dish: str
    grams: float
    gram_source: GramSource
    kcal: Optional[float] = None
    protein: Optional[float] = None
    fat: Optional[float] = None
    carbs: Optional[float] = None
    image_path: Optional[str] = None
    eaten_at: datetime

    model_config = {"from_attributes": True}


class ExerciseEntryRead(BaseModel):
    id: int
    activity: str
    minutes: Optional[float] = None
    kcal: float
    source: Literal["computed", "user"]
    performed_at: datetime

    model_config = {"from_attributes": True}
