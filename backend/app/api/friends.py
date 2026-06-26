"""Friend requests and friendships (auth required).

Friendship is the gate for community invites, so it is kept deliberately simple:
request -> accept. Search and listing expose only the safe PublicUser projection
— never another user's body stats.
"""

from fastapi import APIRouter, Depends
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from ..auth.deps import get_current_user
from ..db import get_db
from ..models.social import Friendship
from ..models.user import User
from ..schemas.social import (
    FriendAccept,
    FriendRequestCreate,
    PublicUser,
)
from ..services import sharing

router = APIRouter(prefix="/friends", tags=["friends"])


@router.post("/request", status_code=201)
def send_request(
    body: FriendRequestCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    if body.addressee_id == user.id:
        raise sharing.ShareError("You cannot friend yourself.")
    if db.get(User, body.addressee_id) is None:
        raise sharing.NotFound("User not found.")

    existing = db.scalar(
        select(Friendship).where(
            or_(
                (Friendship.requester_id == user.id)
                & (Friendship.addressee_id == body.addressee_id),
                (Friendship.requester_id == body.addressee_id)
                & (Friendship.addressee_id == user.id),
            )
        )
    )
    if existing is not None:
        if existing.status == "accepted":
            raise sharing.Conflict("Already friends.")
        # They already requested you -> accepting the existing one.
        if existing.addressee_id == user.id and existing.status == "pending":
            existing.status = "accepted"
            db.commit()
            return {"status": "accepted"}
        raise sharing.Conflict("A request already exists.")

    db.add(
        Friendship(
            requester_id=user.id, addressee_id=body.addressee_id, status="pending"
        )
    )
    db.commit()
    return {"status": "pending"}


@router.post("/accept")
def accept_request(
    body: FriendAccept,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    friendship = db.scalar(
        select(Friendship).where(
            Friendship.requester_id == body.requester_id,
            Friendship.addressee_id == user.id,
            Friendship.status == "pending",
        )
    )
    if friendship is None:
        raise sharing.NotFound("No pending request from that user.")
    friendship.status = "accepted"
    db.commit()
    return {"status": "accepted"}


@router.get("", response_model=list[PublicUser])
def list_friends(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[PublicUser]:
    friends = []
    for fid in sharing.accepted_friend_ids(db, user.id):
        friend = db.get(User, fid)
        if friend is not None:
            friends.append(sharing.public_user(friend))
    return friends


@router.get("/search", response_model=list[PublicUser])
def search(
    handle: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[PublicUser]:
    """Find users by handle (email) prefix. Safe fields only, excludes self."""
    needle = handle.strip().lower()
    if not needle:
        return []
    rows = db.scalars(
        select(User)
        .where(User.email.ilike(f"{needle}%"), User.id != user.id)
        .limit(20)
    ).all()
    return [sharing.public_user(u) for u in rows]
