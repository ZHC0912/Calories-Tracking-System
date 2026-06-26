"""ORM models. Importing this package registers every table on db.Base.metadata
so Alembic autogenerate and Base.metadata.create_all() see them all.
"""

from .log import ExerciseEntry, FoodEntry
from .social import (
    Community,
    CommunityInvite,
    CommunityMember,
    FeedPost,
    Friendship,
    Reaction,
    ShareDefault,
)
from .user import User

__all__ = [
    "User",
    "FoodEntry",
    "ExerciseEntry",
    "Friendship",
    "Community",
    "CommunityMember",
    "CommunityInvite",
    "FeedPost",
    "Reaction",
    "ShareDefault",
]
