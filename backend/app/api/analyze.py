"""POST /analyze — the Phase 1 pipeline.

image (+ optional caption / grams / bucket hints)
    -> model backend recognizes dishes
    -> caption grams merged in
    -> portion resolved per item (user > bucket > estimate)
    -> nutrients looked up (USDA cache/API) and scaled
    -> AnalyzeResponse

Each item carries gram_source so clients can show "estimated" vs "from 250g".
This endpoint reports numbers only — no medical or diet advice.
"""

from fastapi import APIRouter, File, Form, UploadFile

from ..config import get_settings
from ..core.caption import parse_caption
from ..core.dishes import normalize_name
from ..core.model_backend import get_model_backend
from ..core.nutrients import EMPTY_NUTRIENTS, NutrientLookup, scale_nutrients
from ..core.portion import resolve_grams
from ..schemas.analysis import AnalyzeResponse, FoodItem

router = APIRouter(tags=["analysis"])


@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze(
    image: UploadFile = File(...),
    caption: str | None = Form(None),
    grams: float | None = Form(None, description="Explicit grams; applied when exactly one item is recognized."),
    bucket: str | None = Form(None, description="Size bucket hint: small/medium/large (or s/m/l)."),
) -> AnalyzeResponse:
    settings = get_settings()
    backend = get_model_backend(settings.model_backend, settings.model_dir or None)
    lookup = NutrientLookup(api_key=settings.usda_api_key, cache_path=settings.usda_cache_path)

    image_bytes = await image.read()
    items: list[FoodItem] = backend.analyze(image_bytes, caption)

    caption_grams = {
        normalize_name(ci.name): ci.grams
        for ci in parse_caption(caption)
        if ci.grams is not None
    }

    for item in items:
        user_grams = caption_grams.get(normalize_name(item.dish))
        if user_grams is None and grams is not None and len(items) == 1:
            user_grams = grams

        item.grams, item.gram_source = resolve_grams(
            item.dish, user_grams=user_grams, bucket=bucket
        )

        per_100g = lookup.per_100g(item.dish)
        scaled = scale_nutrients(per_100g, item.grams) if per_100g else dict(EMPTY_NUTRIENTS)
        item.kcal = scaled["kcal"]
        item.protein = scaled["protein"]
        item.fat = scaled["fat"]
        item.carbs = scaled["carbs"]

    return AnalyzeResponse(
        items=items,
        total_kcal=_total(items, "kcal"),
        total_protein=_total(items, "protein"),
        total_fat=_total(items, "fat"),
        total_carbs=_total(items, "carbs"),
    )


def _total(items: list[FoodItem], field: str) -> float | None:
    """Sum a nutrient across items, skipping None; None when no item has data."""
    values = [getattr(item, field) for item in items if getattr(item, field) is not None]
    return round(sum(values), 1) if values else None
