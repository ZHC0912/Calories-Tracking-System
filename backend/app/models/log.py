"""ORM tables: meal logs (FoodEntry) and exercise logs (ExerciseEntry).

Timestamps are stored in UTC; the daily report buckets them into the user's
local calendar day. FoodEntry stores the storage path STRING for an image,
never the bytes. `training_eligible` marks rows whose (EXIF-stripped, labeled)
image the user consented to share for future model training — a later step in
model/ consumes those; nothing here exports or trains.
"""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..db import Base


class FoodEntry(Base):
    __tablename__ = "food_entries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )

    dish: Mapped[str] = mapped_column(String(120), nullable=False)
    grams: Mapped[float] = mapped_column(Float, nullable=False)
    # How `grams` was decided: user|bucket|estimate (Phase 1 portion source).
    gram_source: Mapped[str] = mapped_column(String(10), nullable=False)

    # Nutrients are nullable — None means "no data", never a fake zero.
    kcal: Mapped[float | None] = mapped_column(Float, nullable=True)
    protein: Mapped[float | None] = mapped_column(Float, nullable=True)
    fat: Mapped[float | None] = mapped_column(Float, nullable=True)
    carbs: Mapped[float | None] = mapped_column(Float, nullable=True)

    image_path: Mapped[str | None] = mapped_column(String(512), nullable=True)
    eaten_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, index=True, nullable=False
    )
    training_eligible: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )

    user: Mapped["User"] = relationship(back_populates="food_entries")


class ExerciseEntry(Base):
    __tablename__ = "exercise_entries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )

    activity: Mapped[str] = mapped_column(String(60), nullable=False)
    minutes: Mapped[float | None] = mapped_column(Float, nullable=True)
    kcal: Mapped[float] = mapped_column(Float, nullable=False)
    # How `kcal` was decided: computed (from METs) | user (entered directly).
    source: Mapped[str] = mapped_column(String(10), nullable=False)
    performed_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, index=True, nullable=False
    )

    user: Mapped["User"] = relationship(back_populates="exercise_entries")


from .user import User  # noqa: E402  (resolve relationship strings)
