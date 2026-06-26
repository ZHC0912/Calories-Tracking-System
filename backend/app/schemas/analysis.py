"""Pydantic schemas for the meal-analysis pipeline and POST /analyze."""

from typing import Literal, Optional

from pydantic import BaseModel, Field

GramSource = Literal["user", "bucket", "estimate"]


class FoodItem(BaseModel):
    """One recognized food with resolved portion and (optionally) nutrients.

    Nutrient fields are None when no data is available — never fake zeros.
    gram_source tells the client how trustworthy `grams` is, so it can show
    e.g. "estimated" vs "from your 250g".
    """

    dish: str
    grams: float = 0.0
    gram_source: GramSource = "estimate"
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    kcal: Optional[float] = None
    protein: Optional[float] = None
    fat: Optional[float] = None
    carbs: Optional[float] = None


class AnalyzeResponse(BaseModel):
    """Result of analyzing one meal image (+ optional caption)."""

    items: list[FoodItem]
    total_kcal: Optional[float] = None
    total_protein: Optional[float] = None
    total_fat: Optional[float] = None
    total_carbs: Optional[float] = None
