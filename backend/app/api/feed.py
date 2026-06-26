"""Sharing, the community feed, reactions, and share defaults (auth required).

Sharing is ALWAYS explicit: GET /share/preview only computes a share sheet
(nothing persisted); POST /share is the sole write path to any feed. Feeds are
chronological — there is NO ranking or leaderboard. Reactions are limited to the
fixed emoji set, one per user per post.
"""

from datetime import date as date_type
from datetime import datetime
from typing import Optional
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth.deps import get_current_user
from ..db import get_db
from ..models.social import FeedPost, ShareDefault
from ..models.user import User
from ..schemas.social import (
    FeedPostRead,
    ReactionCounts,
    ReactRequest,
    ShareDefaultRead,
    ShareDefaultUpdate,
    SharePreview,
    ShareRequest,
)
from ..services import sharing

router = APIRouter(tags=["feed"])


def _feed_post_read(db: Session, post: FeedPost, caller_id: int) -> FeedPostRead:
    author = db.get(User, post.author_id)
    counts, mine = sharing.reaction_summary(db, post.id, caller_id)
    return FeedPostRead(
        id=post.id,
        community_id=post.community_id,
        author=sharing.public_user(author),
        report_date=post.report_date,
        created_at=post.created_at,
        payload=post.payload,
        reactions=ReactionCounts(counts=counts, my_reaction=mine),
    )


# --- Share -------------------------------------------------------------------


@router.get("/share/preview", response_model=SharePreview)
def share_preview(
    date: Optional[date_type] = None,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SharePreview:
    day = date or datetime.now(ZoneInfo(user.timezone or "UTC")).date()
    return sharing.resolve_share_preview(db, user, day)


@router.post("/share", response_model=list[FeedPostRead], status_code=201)
def share(
    body: ShareRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[FeedPostRead]:
    posts = sharing.perform_share(db, user, body)
    return [_feed_post_read(db, p, user.id) for p in posts]


# --- Feed --------------------------------------------------------------------


@router.get("/feed/{community_id}", response_model=list[FeedPostRead])
def community_feed(
    community_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[FeedPostRead]:
    sharing.require_member(db, community_id, user.id)
    posts = db.scalars(
        select(FeedPost)
        .where(FeedPost.community_id == community_id)
        .order_by(FeedPost.created_at.desc())  # chronological, newest first
    ).all()
    return [_feed_post_read(db, p, user.id) for p in posts]


@router.post("/feed/{post_id}/react", response_model=ReactionCounts)
def react(
    post_id: int,
    body: ReactRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReactionCounts:
    post = db.get(FeedPost, post_id)
    if post is None:
        raise sharing.NotFound("Post not found.")
    # Only members of the post's community may react.
    sharing.require_member(db, post.community_id, user.id)
    sharing.set_reaction(db, post, user.id, body.emoji)
    counts, mine = sharing.reaction_summary(db, post.id, user.id)
    return ReactionCounts(counts=counts, my_reaction=mine)


@router.delete("/feed/{post_id}/react", response_model=ReactionCounts)
def unreact(
    post_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReactionCounts:
    post = db.get(FeedPost, post_id)
    if post is None:
        raise sharing.NotFound("Post not found.")
    sharing.require_member(db, post.community_id, user.id)
    sharing.remove_reaction(db, post.id, user.id)
    counts, mine = sharing.reaction_summary(db, post.id, user.id)
    return ReactionCounts(counts=counts, my_reaction=mine)


# --- Share defaults ----------------------------------------------------------


@router.get("/share/defaults/{friend_id}", response_model=ShareDefaultRead)
def get_share_default(
    friend_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ShareDefaultRead:
    if not sharing.are_friends(db, user.id, friend_id):
        raise sharing.Forbidden("Not friends with that user.")
    friend = db.get(User, friend_id)
    default = db.scalar(
        select(ShareDefault).where(
            ShareDefault.owner_id == user.id, ShareDefault.friend_id == friend_id
        )
    )
    if default is None:
        # Unset defaults read back as the safe baseline (body-derived OFF).
        return ShareDefaultRead(friend=sharing.public_user(friend), enabled=False)
    return ShareDefaultRead(
        friend=sharing.public_user(friend),
        enabled=default.enabled,
        include_net_calories=default.include_net_calories,
        include_macros=default.include_macros,
        include_food_images=default.include_food_images,
        include_target=default.include_target,
    )


@router.put("/share/defaults/{friend_id}", response_model=ShareDefaultRead)
def set_share_default(
    friend_id: int,
    body: ShareDefaultUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ShareDefaultRead:
    if not sharing.are_friends(db, user.id, friend_id):
        raise sharing.Forbidden("Not friends with that user.")
    friend = db.get(User, friend_id)

    default = db.scalar(
        select(ShareDefault).where(
            ShareDefault.owner_id == user.id, ShareDefault.friend_id == friend_id
        )
    )
    if default is None:
        default = ShareDefault(owner_id=user.id, friend_id=friend_id)
        db.add(default)

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(default, field, value)
    db.commit()
    db.refresh(default)

    return ShareDefaultRead(
        friend=sharing.public_user(friend),
        enabled=default.enabled,
        include_net_calories=default.include_net_calories,
        include_macros=default.include_macros,
        include_food_images=default.include_food_images,
        include_target=default.include_target,
    )
