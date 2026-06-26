"""Pydantic schemas for the social layer.

Two safety rules show up directly here:
  * No free-text fields anywhere — reactions are constrained to the fixed emoji
    set; shares carry only boolean part-toggles, never a message.
  * Public/social reads expose ONLY a safe handle + display name + internal id.
    Profile stats (weight/height/age/BMI) are never part of any social schema.
"""

from datetime import date as date_type
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field, field_validator

from ..models.social import ALLOWED_REACTIONS

# --- Users (safe public projection) ------------------------------------------


class PublicUser(BaseModel):
    """The only shape another user is ever exposed as. No body stats, ever."""

    id: int
    handle: EmailStr  # email doubles as the lookup handle in Phase 3
    display_name: str


# --- Friends -----------------------------------------------------------------


class FriendRequestCreate(BaseModel):
    addressee_id: int


class FriendAccept(BaseModel):
    requester_id: int


class FriendRequestRead(BaseModel):
    id: int
    requester: PublicUser
    addressee: PublicUser
    status: str
    created_at: datetime


# --- Communities -------------------------------------------------------------


class CommunityCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)


class CommunityRead(BaseModel):
    id: int
    name: str
    owner_id: int
    member_count: int


class CommunityMemberRead(BaseModel):
    user: PublicUser
    role: str
    joined_at: datetime


class InviteCreate(BaseModel):
    invitee_id: int


class InviteRead(BaseModel):
    id: int
    community_id: int
    community_name: str
    inviter: PublicUser
    status: str
    created_at: datetime


# --- Share parts / defaults --------------------------------------------------


class ShareParts(BaseModel):
    """Which parts of a daily report to include. Body-derived parts (target/
    remaining) default OFF — they are only included when explicitly set True."""

    include_net_calories: bool = True
    include_macros: bool = False
    include_food_images: bool = False
    include_target: bool = False  # body-derived; explicit opt-in only


class ShareDefaultRead(ShareParts):
    friend: PublicUser
    enabled: bool = True


class ShareDefaultUpdate(BaseModel):
    enabled: Optional[bool] = None
    include_net_calories: Optional[bool] = None
    include_macros: Optional[bool] = None
    include_food_images: Optional[bool] = None
    include_target: Optional[bool] = None


# --- Share preview / request -------------------------------------------------


class PreselectedFriend(BaseModel):
    """A friend pre-ticked on the share sheet, with their default parts."""

    friend: PublicUser
    parts: ShareParts


class SharePreview(BaseModel):
    """What the share sheet shows. Computed only — nothing is persisted here."""

    date: date_type
    has_report: bool
    preselected_friends: list[PreselectedFriend]
    addable_friends: list[PublicUser]
    my_communities: list[CommunityRead]


class ShareRequest(BaseModel):
    """The explicit send. Nothing reaches a feed without one of these."""

    date: date_type
    parts: ShareParts = ShareParts()
    community_ids: list[int] = Field(default_factory=list)

    @field_validator("community_ids")
    @classmethod
    def _at_least_one_target(cls, v: list[int]) -> list[int]:
        if not v:
            raise ValueError("Share to at least one community.")
        return v


# --- Feed --------------------------------------------------------------------


class ReactionCounts(BaseModel):
    counts: dict[str, int]  # emoji -> count, only for the allowed set
    my_reaction: Optional[str] = None


class FeedPostRead(BaseModel):
    id: int
    community_id: int
    author: PublicUser
    report_date: date_type
    created_at: datetime
    payload: dict  # the frozen snapshot of shared parts
    reactions: ReactionCounts


class ReactRequest(BaseModel):
    emoji: str

    @field_validator("emoji")
    @classmethod
    def _must_be_allowed(cls, v: str) -> str:
        if v not in ALLOWED_REACTIONS:
            raise ValueError(
                f"Reaction must be one of {' '.join(sorted(ALLOWED_REACTIONS))}."
            )
        return v
