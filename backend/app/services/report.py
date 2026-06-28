"""Build the daily report by aggregating a user's logs for one calendar day.

Timestamps are stored in UTC; a "day" is the user's LOCAL calendar day. We
convert the local day's [start, end) into a UTC window and query within it, so
a meal at 1 a.m. in Kuala Lumpur lands on the right local date.
"""

from datetime import date as date_type
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models.log import ExerciseEntry, FoodEntry
from ..models.user import User
from ..schemas.log import ExerciseEntryRead, FoodEntryRead
from ..schemas.report import DailyReport
from . import target as target_service


def utc_window(day: date_type, tz_name: str) -> tuple[datetime, datetime]:
    """UTC [start, end) bounds for a local calendar day, as naive UTC datetimes.

    Naive because timestamps are stored naive-UTC (portable across SQLite and
    Postgres); we compare like with like.
    """
    tz = ZoneInfo(tz_name)
    start_local = datetime(day.year, day.month, day.day, tzinfo=tz)
    end_local = start_local + timedelta(days=1)
    start_utc = start_local.astimezone(ZoneInfo("UTC")).replace(tzinfo=None)
    end_utc = end_local.astimezone(ZoneInfo("UTC")).replace(tzinfo=None)
    return start_utc, end_utc


def _target_for(user: User) -> float | None:
    """Daily target: the user's override if set, else the computed one (None when
    the profile lacks the stats needed to compute it)."""
    computed = None
    if None not in (user.weight_kg, user.height_cm, user.age, user.sex):
        bmr = target_service.bmr_mifflin_st_jeor(
            user.weight_kg, user.height_cm, user.age, user.sex
        )
        tdee = target_service.tdee(bmr, user.activity_level or "sedentary")
        computed = target_service.daily_target(tdee, user.goal or "maintain")
    return target_service.effective_target(user.target_kcal_override, computed)


def build_daily_report(db: Session, user: User, day: date_type) -> DailyReport:
    tz_name = user.timezone or "UTC"
    start_utc, end_utc = utc_window(day, tz_name)

    foods = db.scalars(
        select(FoodEntry)
        .where(
            FoodEntry.user_id == user.id,
            FoodEntry.eaten_at >= start_utc,
            FoodEntry.eaten_at < end_utc,
        )
        .order_by(FoodEntry.eaten_at)
    ).all()
    exercises = db.scalars(
        select(ExerciseEntry)
        .where(
            ExerciseEntry.user_id == user.id,
            ExerciseEntry.performed_at >= start_utc,
            ExerciseEntry.performed_at < end_utc,
        )
        .order_by(ExerciseEntry.performed_at)
    ).all()

    total_intake = round(sum(f.kcal or 0.0 for f in foods), 1)
    total_burned = round(sum(e.kcal for e in exercises), 1)
    net = round(total_intake - total_burned, 1)

    target = _target_for(user)
    remaining = round(target - net, 1) if target is not None else None

    return DailyReport(
        date=day,
        timezone=tz_name,
        total_intake_kcal=total_intake,
        total_burned_kcal=total_burned,
        net_kcal=net,
        target_kcal=target,
        remaining_kcal=remaining,
        total_protein=round(sum(f.protein or 0.0 for f in foods), 1),
        total_fat=round(sum(f.fat or 0.0 for f in foods), 1),
        total_carbs=round(sum(f.carbs or 0.0 for f in foods), 1),
        meals=[FoodEntryRead.model_validate(f) for f in foods],
        exercises=[ExerciseEntryRead.model_validate(e) for e in exercises],
        note=target_service.NOT_MEDICAL_ADVICE,
    )
