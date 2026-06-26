"""Meal & exercise logging endpoints (auth required).

Food logging REUSES the Phase 1 core pipeline — portion.resolve_grams and the
USDA nutrient lookup/scaling — so calorie numbers are recomputed server-side
from the confirmed dish + portion, never trusted from the client. Nothing here
duplicates core logic.

Image handling: an optional meal photo is EXIF-stripped before storage (privacy
for everyone). If the user opted in (allow_training_use), an EXIF-stripped copy
is also written to a separate 'training' namespace and the entry is flagged
training_eligible with its confirmed dish as the label — a consented, labeled
record for a FUTURE model-retraining step in model/ (not built here).
"""

import json
import uuid

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    UploadFile,
    status,
)
from sqlalchemy.orm import Session

from ..auth.deps import get_current_user
from ..config import get_settings
from ..core.exercise import log_exercise
from ..core.nutrients import EMPTY_NUTRIENTS, NutrientLookup, scale_nutrients
from ..core.portion import resolve_grams
from ..db import get_db
from ..models.log import ExerciseEntry, FoodEntry
from ..models.user import User
from ..schemas.log import (
    ExerciseEntryRead,
    FoodEntryRead,
    LogExerciseRequest,
    LogFoodRequest,
)
from ..services.images import strip_exif
from ..storage.local import LocalDiskStorage

router = APIRouter(prefix="/log", tags=["logging"])


def _store_image(image_bytes: bytes, opt_in: bool) -> str:
    """EXIF-strip and store a meal image; returns the path string to persist.

    When opt_in, also writes an EXIF-stripped copy to the 'training' namespace
    for later (consented) model training.
    """
    settings = get_settings()
    storage = LocalDiskStorage(settings.storage_dir)
    clean = strip_exif(image_bytes)
    name = f"{uuid.uuid4().hex}.jpg"
    path = storage.save(clean, name, namespace="meals")
    if opt_in:
        # Separate namespace keeps consented training data apart from personal
        # history. model/ will consume these later; we only persist them here.
        storage.save(clean, name, namespace="training")
    return path


@router.post("/food", response_model=list[FoodEntryRead], status_code=status.HTTP_201_CREATED)
async def log_food(
    items: str = Form(..., description="JSON body matching LogFoodRequest."),
    image: UploadFile | None = File(default=None),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[FoodEntryRead]:
    try:
        payload = LogFoodRequest.model_validate_json(items)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)
        )

    image_path: str | None = None
    if image is not None:
        image_bytes = await image.read()
        if image_bytes:
            image_path = _store_image(image_bytes, user.allow_training_use)

    settings = get_settings()
    lookup = NutrientLookup(
        api_key=settings.usda_api_key, cache_path=settings.usda_cache_path
    )

    entries: list[FoodEntry] = []
    for item in payload.items:
        grams, gram_source = resolve_grams(
            item.dish, user_grams=item.grams, bucket=item.bucket
        )
        per_100g = lookup.per_100g(item.dish)
        scaled = scale_nutrients(per_100g, grams) if per_100g else dict(EMPTY_NUTRIENTS)
        entries.append(
            FoodEntry(
                user_id=user.id,
                dish=item.dish,
                grams=grams,
                gram_source=gram_source,
                kcal=scaled["kcal"],
                protein=scaled["protein"],
                fat=scaled["fat"],
                carbs=scaled["carbs"],
                image_path=image_path,
                training_eligible=user.allow_training_use and image_path is not None,
            )
        )

    db.add_all(entries)
    db.commit()
    for entry in entries:
        db.refresh(entry)
    return [FoodEntryRead.model_validate(e) for e in entries]


@router.post(
    "/exercise", response_model=ExerciseEntryRead, status_code=status.HTTP_201_CREATED
)
def log_exercise_entry(
    body: LogExerciseRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ExerciseEntryRead:
    try:
        # Direct kcal -> source 'user'; activity+minutes -> MET 'computed'
        # (needs the user's weight). Phase 1 core does the math.
        result = log_exercise(
            activity=body.activity,
            weight_kg=user.weight_kg,
            hours=(body.minutes / 60.0) if body.minutes is not None else None,
            kcal=body.kcal,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)
        )

    entry = ExerciseEntry(
        user_id=user.id,
        activity=result["activity"],
        minutes=body.minutes,
        kcal=result["kcal"],
        source=result["source"],
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return ExerciseEntryRead.model_validate(entry)
