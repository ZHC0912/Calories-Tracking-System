"""Pydantic schemas for users: register/login, tokens, profile read/update.

ProfileSummary bundles the stored stats with the COMPUTED BMI + calorie target
and the not-medical-advice disclaimers, so a client gets everything to display
in one GET. The calorie target is never persisted — it is derived here.
"""

from typing import Literal, Optional

from pydantic import BaseModel, EmailStr, Field

Sex = Literal["male", "female"]
ActivityLevel = Literal["sedentary", "light", "moderate", "active", "very_active"]
Goal = Literal["lose", "maintain", "gain"]


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    # Optional here (older clients/tests omit it); the app requires it. Stored as
    # the social display name. Whitespace-only is rejected by min_length after
    # the app trims it.
    username: Optional[str] = Field(default=None, min_length=1, max_length=30)


class LoginRequest(BaseModel):
    # The login handle: a username or an email. `email` is kept for backward
    # compatibility (older clients/tests posted an email here). The endpoint
    # matches a username case-insensitively or falls back to the email.
    username: Optional[str] = Field(default=None, max_length=254)
    email: Optional[str] = Field(default=None, max_length=254)
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class ProfileUpdate(BaseModel):
    """Partial update — every field optional; only provided ones change.

    To CLEAR the custom calorie target (revert to the computed one), send
    `target_kcal_override: null` explicitly; omitting the field leaves it as-is.
    """

    username: Optional[str] = Field(default=None, min_length=1, max_length=30)
    weight_kg: Optional[float] = Field(default=None, gt=0, le=500)
    height_cm: Optional[float] = Field(default=None, gt=0, le=300)
    age: Optional[int] = Field(default=None, gt=0, le=130)
    sex: Optional[Sex] = None
    activity_level: Optional[ActivityLevel] = None
    goal: Optional[Goal] = None
    timezone: Optional[str] = None
    allow_training_use: Optional[bool] = None
    target_kcal_override: Optional[float] = Field(default=None, gt=0, le=20000)


class ProfileSummary(BaseModel):
    """Profile read: stored stats + computed BMI/target + disclaimers.

    Computed fields are None until the profile has the stats they need.
    """

    email: EmailStr
    username: Optional[str] = None
    weight_kg: Optional[float] = None
    height_cm: Optional[float] = None
    age: Optional[int] = None
    sex: Optional[Sex] = None
    activity_level: Optional[ActivityLevel] = None
    goal: Optional[Goal] = None
    timezone: str = "UTC"
    allow_training_use: bool = False

    # Computed (services/target.py) — estimates, not medical advice.
    bmi: Optional[float] = None
    bmi_note: Optional[str] = None
    bmr_kcal: Optional[float] = None
    tdee_kcal: Optional[float] = None
    # target_kcal is the EFFECTIVE target: the user's override if set, else the
    # computed one. target_kcal_override is the raw stored override (or None) and
    # target_is_custom says which one target_kcal reflects.
    target_kcal: Optional[float] = None
    target_kcal_override: Optional[float] = None
    target_is_custom: bool = False
    activity_guidance: str
    note: str
