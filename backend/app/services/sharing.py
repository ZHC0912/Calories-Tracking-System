"""Social rules: friendship checks, community membership/cap, snapshot building,
and the single explicit share path.

This module is the brain of Phase 3. The API layer stays thin: it authenticates,
calls these helpers, and serializes results. Typed ShareError subclasses carry
the HTTP status so a single handler in main.py maps them.

Hard rules enforced here (not just in the schema):
  * Community invites require an EXISTING accepted friendship.
  * Community size is capped at MAX_COMMUNITY_MEMBERS, enforced atomically.
  * A share snapshot contains ONLY the parts the author chose; body-derived
    parts (target/remaining) are dropped unless explicitly included.
  * Nothing is written to a feed except through perform_share().
"""

from datetime import date as date_type

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from ..models.social import (
    MAX_COMMUNITY_MEMBERS,
    Community,
    CommunityMember,
    FeedPost,
    Friendship,
    Reaction,
    ShareDefault,
)
from ..models.user import User
from ..schemas.report import DailyReport
from ..schemas.social import (
    CommunityRead,
    PreselectedFriend,
    PublicUser,
    ShareParts,
    SharePreview,
    ShareRequest,
)
from .report import build_daily_report


# --- Typed errors (mapped to HTTP in main.py) --------------------------------


class ShareError(Exception):
    status_code = 400


class Forbidden(ShareError):
    status_code = 403


class NotFound(ShareError):
    status_code = 404


class Conflict(ShareError):
    status_code = 409


# --- Safe public projection --------------------------------------------------


def public_user(user: User) -> PublicUser:
    """Project a User to the ONLY shape exposed socially — never body stats."""
    return PublicUser(
        id=user.id,
        handle=user.email,
        display_name=user.email.split("@", 1)[0],
    )


def _public_by_id(db: Session, user_id: int) -> PublicUser:
    user = db.get(User, user_id)
    if user is None:
        raise NotFound("User not found.")
    return public_user(user)


# --- Friendship --------------------------------------------------------------


def are_friends(db: Session, a_id: int, b_id: int) -> bool:
    """True iff an accepted friendship exists between the two, either direction."""
    if a_id == b_id:
        return False
    row = db.scalar(
        select(Friendship.id).where(
            Friendship.status == "accepted",
            or_(
                (Friendship.requester_id == a_id) & (Friendship.addressee_id == b_id),
                (Friendship.requester_id == b_id) & (Friendship.addressee_id == a_id),
            ),
        )
    )
    return row is not None


def accepted_friend_ids(db: Session, user_id: int) -> list[int]:
    rows = db.execute(
        select(Friendship.requester_id, Friendship.addressee_id).where(
            Friendship.status == "accepted",
            or_(
                Friendship.requester_id == user_id,
                Friendship.addressee_id == user_id,
            ),
        )
    ).all()
    out: list[int] = []
    for requester_id, addressee_id in rows:
        out.append(addressee_id if requester_id == user_id else requester_id)
    return out


# --- Community membership / cap ----------------------------------------------


def is_member(db: Session, community_id: int, user_id: int) -> bool:
    return (
        db.scalar(
            select(CommunityMember.id).where(
                CommunityMember.community_id == community_id,
                CommunityMember.user_id == user_id,
            )
        )
        is not None
    )


def require_member(db: Session, community_id: int, user_id: int) -> None:
    if db.get(Community, community_id) is None:
        raise NotFound("Community not found.")
    if not is_member(db, community_id, user_id):
        raise Forbidden("You are not a member of this community.")


def member_count(db: Session, community_id: int) -> int:
    return db.scalar(
        select(func.count()).select_from(CommunityMember).where(
            CommunityMember.community_id == community_id
        )
    )


def add_member_atomically(
    db: Session, community_id: int, user_id: int, role: str = "member"
) -> CommunityMember:
    """Add a member, never letting the community exceed MAX_COMMUNITY_MEMBERS.

    The community row is locked (with_for_update) so concurrent joins serialize
    on Postgres; SQLite serializes writes at the database level, so the
    count-then-insert is race-free there too.
    """
    community = db.scalars(
        select(Community).where(Community.id == community_id).with_for_update()
    ).one_or_none()
    if community is None:
        raise NotFound("Community not found.")

    if is_member(db, community_id, user_id):
        raise Conflict("Already a member.")

    if member_count(db, community_id) >= MAX_COMMUNITY_MEMBERS:
        raise Conflict(
            f"Community is full (max {MAX_COMMUNITY_MEMBERS} members)."
        )

    member = CommunityMember(community_id=community_id, user_id=user_id, role=role)
    db.add(member)
    db.flush()
    return member


def community_read(db: Session, community: Community) -> CommunityRead:
    return CommunityRead(
        id=community.id,
        name=community.name,
        owner_id=community.owner_id,
        member_count=member_count(db, community.id),
    )


# --- Share snapshot ----------------------------------------------------------


def build_snapshot(report: DailyReport, parts: ShareParts) -> dict:
    """Frozen payload of ONLY the chosen parts.

    Always includes positive, non-body consistency signals (did they log, how
    many items). Net calories / macros / food images are opt-in. Target and
    remaining-vs-target are body-derived and included ONLY when parts.include_
    target is explicitly True. Raw profile stats are never present here.
    """
    snapshot: dict = {
        "date": report.date.isoformat(),
        "logged": bool(report.meals or report.exercises),
        "meals_count": len(report.meals),
        "exercises_count": len(report.exercises),
    }

    if parts.include_net_calories:
        snapshot["total_intake_kcal"] = report.total_intake_kcal
        snapshot["total_burned_kcal"] = report.total_burned_kcal
        snapshot["net_kcal"] = report.net_kcal

    if parts.include_macros:
        snapshot["total_protein"] = report.total_protein
        snapshot["total_fat"] = report.total_fat
        snapshot["total_carbs"] = report.total_carbs

    if parts.include_food_images:
        snapshot["food_images"] = [
            {"dish": m.dish, "image_path": m.image_path}
            for m in report.meals
            if m.image_path
        ]

    if parts.include_target:  # body-derived — explicit opt-in only
        snapshot["target_kcal"] = report.target_kcal
        snapshot["remaining_kcal"] = report.remaining_kcal

    return snapshot


def _default_parts_for(default: ShareDefault | None) -> ShareParts:
    if default is None:
        return ShareParts()
    return ShareParts(
        include_net_calories=default.include_net_calories,
        include_macros=default.include_macros,
        include_food_images=default.include_food_images,
        include_target=default.include_target,
    )


def resolve_share_preview(db: Session, user: User, day: date_type) -> SharePreview:
    """Build the share sheet for a date. Computes only — persists nothing."""
    report = build_daily_report(db, user, day)
    has_report = bool(report.meals or report.exercises)

    friend_ids = accepted_friend_ids(db, user.id)
    defaults = {
        d.friend_id: d
        for d in db.scalars(
            select(ShareDefault).where(ShareDefault.owner_id == user.id)
        ).all()
    }

    preselected: list[PreselectedFriend] = []
    addable: list[PublicUser] = []
    for fid in friend_ids:
        friend = db.get(User, fid)
        if friend is None:
            continue
        default = defaults.get(fid)
        if default is not None and default.enabled:
            preselected.append(
                PreselectedFriend(
                    friend=public_user(friend), parts=_default_parts_for(default)
                )
            )
        else:
            addable.append(public_user(friend))

    my_communities = [
        community_read(db, c)
        for c in db.scalars(
            select(Community)
            .join(CommunityMember, CommunityMember.community_id == Community.id)
            .where(CommunityMember.user_id == user.id)
        ).all()
    ]

    return SharePreview(
        date=day,
        has_report=has_report,
        preselected_friends=preselected,
        addable_friends=addable,
        my_communities=my_communities,
    )


def perform_share(db: Session, user: User, request: ShareRequest) -> list[FeedPost]:
    """The ONLY path that writes to a feed, and only on explicit request.

    Validates membership of every target community, builds the snapshot from the
    chosen parts, and creates one FeedPost per community.
    """
    for community_id in request.community_ids:
        require_member(db, community_id, user.id)

    report = build_daily_report(db, user, request.date)
    snapshot = build_snapshot(report, request.parts)

    posts: list[FeedPost] = []
    for community_id in request.community_ids:
        post = FeedPost(
            author_id=user.id,
            community_id=community_id,
            report_date=request.date,
            payload=snapshot,
        )
        db.add(post)
        posts.append(post)
    db.commit()
    for post in posts:
        db.refresh(post)
    return posts


# --- Reactions ---------------------------------------------------------------


def reaction_summary(db: Session, post_id: int, user_id: int) -> tuple[dict, str | None]:
    """(emoji -> count, the caller's own reaction or None)."""
    rows = db.execute(
        select(Reaction.emoji, func.count())
        .where(Reaction.feed_post_id == post_id)
        .group_by(Reaction.emoji)
    ).all()
    counts = {emoji: n for emoji, n in rows}
    mine = db.scalar(
        select(Reaction.emoji).where(
            Reaction.feed_post_id == post_id, Reaction.user_id == user_id
        )
    )
    return counts, mine


def set_reaction(db: Session, post: FeedPost, user_id: int, emoji: str) -> None:
    """Set or change the caller's single reaction on a post (membership checked
    by the caller)."""
    existing = db.scalar(
        select(Reaction).where(
            Reaction.feed_post_id == post.id, Reaction.user_id == user_id
        )
    )
    if existing is None:
        db.add(Reaction(feed_post_id=post.id, user_id=user_id, emoji=emoji))
    else:
        existing.emoji = emoji
    db.commit()


def remove_reaction(db: Session, post_id: int, user_id: int) -> None:
    existing = db.scalar(
        select(Reaction).where(
            Reaction.feed_post_id == post_id, Reaction.user_id == user_id
        )
    )
    if existing is not None:
        db.delete(existing)
        db.commit()
