"""Profile endpoints: read/update body stats (kg/cm), goal, timezone, consent.

GET returns a ProfileSummary with the COMPUTED BMI, BMR/TDEE, daily target,
activity guidance, and the not-medical-advice disclaimers. All health numbers
are estimates.
"""

from zoneinfo import available_timezones

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..auth.deps import get_current_user
from ..db import get_db
from ..models.user import User
from ..schemas.user import ProfileSummary, ProfileUpdate
from ..services import target as target_service

router = APIRouter(prefix="/profile", tags=["profile"])

_VALID_TIMEZONES = available_timezones()


def _summary(user: User) -> ProfileSummary:
    """Assemble the stored profile plus computed estimates."""
    bmi = bmr = tdee = computed_target = None
    bmi_note = None

    if user.weight_kg is not None and user.height_cm is not None:
        bmi = target_service.bmi(user.weight_kg, user.height_cm)
        bmi_note = target_service.BMI_CAVEAT

    if None not in (user.weight_kg, user.height_cm, user.age, user.sex):
        bmr = target_service.bmr_mifflin_st_jeor(
            user.weight_kg, user.height_cm, user.age, user.sex
        )
        tdee = target_service.tdee(bmr, user.activity_level or "sedentary")
        computed_target = target_service.daily_target(tdee, user.goal or "maintain")

    effective_target = target_service.effective_target(
        user.target_kcal_override, computed_target
    )

    return ProfileSummary(
        email=user.email,
        username=user.username,
        weight_kg=user.weight_kg,
        height_cm=user.height_cm,
        age=user.age,
        sex=user.sex,
        activity_level=user.activity_level,
        goal=user.goal,
        timezone=user.timezone,
        allow_training_use=user.allow_training_use,
        bmi=bmi,
        bmi_note=bmi_note,
        bmr_kcal=bmr,
        tdee_kcal=tdee,
        target_kcal=effective_target,
        target_kcal_override=user.target_kcal_override,
        target_is_custom=user.target_kcal_override is not None,
        activity_guidance=target_service.ACTIVITY_GUIDANCE,
        note=target_service.NOT_MEDICAL_ADVICE,
    )


@router.get("", response_model=ProfileSummary)
def read_profile(user: User = Depends(get_current_user)) -> ProfileSummary:
    return _summary(user)


@router.put("", response_model=ProfileSummary)
def update_profile(
    body: ProfileUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProfileSummary:
    fields = body.model_dump(exclude_unset=True)

    if "timezone" in fields and fields["timezone"] not in _VALID_TIMEZONES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unknown timezone {fields['timezone']!r} (use an IANA name).",
        )

    if "username" in fields and fields["username"] is not None:
        fields["username"] = fields["username"].strip() or None
        new_username = fields["username"]
        if new_username is not None:
            clash = db.scalar(
                select(User).where(
                    func.lower(User.username) == new_username.lower(),
                    User.id != user.id,
                )
            )
            if clash is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Username already taken.",
                )

    # A provided override is clamped to the safe floor; an explicit null clears it.
    if fields.get("target_kcal_override") is not None:
        fields["target_kcal_override"] = target_service.clamp_target(
            fields["target_kcal_override"]
        )

    for name, value in fields.items():
        setattr(user, name, value)
    db.commit()
    db.refresh(user)
    return _summary(user)
