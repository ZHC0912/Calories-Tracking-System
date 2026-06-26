"""ORM table: users — credentials, body stats (kg/cm), and consent flag.

Identity note (future-proofing for WhatsApp etc.): the login handle here is
`email`, but the stable identity is the integer `id`. Foreign keys and JWTs
reference `id`, never `email`, so a later phase can add a separate `identities`
table (provider, handle -> user_id) for phone/WhatsApp logins without reworking
this row. The calorie target is NOT stored — it is computed on demand from
these stats in services/target.py.
"""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..db import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )

    # Profile (metric units). All nullable: a user exists before completing it.
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    height_cm: Mapped[float | None] = mapped_column(Float, nullable=True)
    age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sex: Mapped[str | None] = mapped_column(String(10), nullable=True)  # male|female
    activity_level: Mapped[str | None] = mapped_column(String(20), nullable=True)
    goal: Mapped[str | None] = mapped_column(String(10), nullable=True)  # lose|maintain|gain
    timezone: Mapped[str] = mapped_column(String(64), default="UTC", nullable=False)

    # Opt-in consent to use this user's (EXIF-stripped) meal images for future
    # model training. Defaults FALSE — privacy-respecting by default.
    allow_training_use: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )

    food_entries: Mapped[list["FoodEntry"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    exercise_entries: Mapped[list["ExerciseEntry"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


from .log import ExerciseEntry, FoodEntry  # noqa: E402  (resolve relationship strings)
