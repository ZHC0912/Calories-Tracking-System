"""ORM tables for the social layer: friendships, communities, invites, feed.

Design guardrails baked into the schema:
  * NO free text anywhere — there is no message/comment/caption column. The
    only user-authored social signal is a Reaction from a FIXED emoji set.
  * A FeedPost stores a SNAPSHOT (JSON) of exactly the report parts the author
    chose to share at share time — never recomputed, never more than was shared.
  * Communities are friend-gated and hard-capped at MAX_COMMUNITY_MEMBERS; the
    cap is enforced atomically in services/sharing.py, not by the schema alone.

These tables intentionally carry FK columns but NO relationships back onto User,
so Phases 1–2 models stay untouched; joins are done with explicit queries.
"""

from datetime import date as date_type
from datetime import datetime

from sqlalchemy import (
    JSON,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from ..db import Base

# Hard cap on community size (owner included). Enforced atomically on join.
MAX_COMMUNITY_MEMBERS = 10

# The ONLY reactions allowed. Reactions are not free input — anything outside
# this set is rejected. Positive/encouraging signals only; no thumbs-down.
ALLOWED_REACTIONS: frozenset[str] = frozenset({"👍", "💪", "🔥", "👏"})


class Friendship(Base):
    __tablename__ = "friendships"
    __table_args__ = (
        UniqueConstraint("requester_id", "addressee_id", name="uq_friendship_pair"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    requester_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    addressee_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    # pending | accepted | blocked
    status: Mapped[str] = mapped_column(String(10), default="pending", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )


class Community(Base):
    __tablename__ = "communities"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    owner_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )


class CommunityMember(Base):
    __tablename__ = "community_members"
    __table_args__ = (
        UniqueConstraint("community_id", "user_id", name="uq_member_once"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    community_id: Mapped[int] = mapped_column(
        ForeignKey("communities.id", ondelete="CASCADE"), index=True, nullable=False
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    role: Mapped[str] = mapped_column(String(10), default="member", nullable=False)
    joined_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )


class CommunityInvite(Base):
    __tablename__ = "community_invites"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    community_id: Mapped[int] = mapped_column(
        ForeignKey("communities.id", ondelete="CASCADE"), index=True, nullable=False
    )
    inviter_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    invitee_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    # pending | accepted | declined
    status: Mapped[str] = mapped_column(String(10), default="pending", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )


class FeedPost(Base):
    __tablename__ = "feed_posts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    author_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    community_id: Mapped[int] = mapped_column(
        ForeignKey("communities.id", ondelete="CASCADE"), index=True, nullable=False
    )
    report_date: Mapped[date_type] = mapped_column(Date, nullable=False)
    # Frozen snapshot of ONLY the shared parts. No text column by design.
    payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, index=True, nullable=False
    )


class Reaction(Base):
    __tablename__ = "reactions"
    __table_args__ = (
        # One reaction per user per post (changeable, not duplicated).
        UniqueConstraint("feed_post_id", "user_id", name="uq_reaction_once"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    feed_post_id: Mapped[int] = mapped_column(
        ForeignKey("feed_posts.id", ondelete="CASCADE"), index=True, nullable=False
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    emoji: Mapped[str] = mapped_column(String(8), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )


class ShareDefault(Base):
    """Pre-selected recipients + granularity for the share sheet.

    This only PRE-TICKS the share dialog; it never auto-sends. The actual send
    is always an explicit POST /share. Body-derived parts default to False.
    """

    __tablename__ = "share_defaults"
    __table_args__ = (
        UniqueConstraint("owner_id", "friend_id", name="uq_sharedefault_pair"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    owner_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    friend_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    include_food_images: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    include_net_calories: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    include_macros: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    # Body-derived (depends on weight/height/age) — OFF unless explicitly chosen.
    include_target: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
