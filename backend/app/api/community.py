"""Communities: small, invite-only, friend-gated groups capped at 10 (auth required).

Authorization is enforced on every route: only members read a community's
members; you may only invite accepted friends into communities you belong to;
joining is capped atomically at MAX_COMMUNITY_MEMBERS.
"""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth.deps import get_current_user
from ..db import get_db
from ..models.social import (
    Community,
    CommunityInvite,
    CommunityMember,
    Friendship,  # noqa: F401  (kept for clarity; friendship checks via sharing)
)
from ..models.user import User
from ..schemas.social import (
    CommunityCreate,
    CommunityMemberRead,
    CommunityRead,
    InviteCreate,
    InviteRead,
)
from ..services import sharing

router = APIRouter(prefix="/community", tags=["community"])


@router.post("", response_model=CommunityRead, status_code=201)
def create_community(
    body: CommunityCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CommunityRead:
    community = Community(name=body.name, owner_id=user.id)
    db.add(community)
    db.flush()  # assign id
    sharing.add_member_atomically(db, community.id, user.id, role="owner")
    db.commit()
    db.refresh(community)
    return sharing.community_read(db, community)


@router.get("", response_model=list[CommunityRead])
def my_communities(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[CommunityRead]:
    rows = db.scalars(
        select(Community)
        .join(CommunityMember, CommunityMember.community_id == Community.id)
        .where(CommunityMember.user_id == user.id)
    ).all()
    return [sharing.community_read(db, c) for c in rows]


@router.get("/invites", response_model=list[InviteRead])
def my_invites(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[InviteRead]:
    rows = db.scalars(
        select(CommunityInvite).where(
            CommunityInvite.invitee_id == user.id,
            CommunityInvite.status == "pending",
        )
    ).all()
    out: list[InviteRead] = []
    for inv in rows:
        community = db.get(Community, inv.community_id)
        inviter = db.get(User, inv.inviter_id)
        if community is None or inviter is None:
            continue
        out.append(
            InviteRead(
                id=inv.id,
                community_id=inv.community_id,
                community_name=community.name,
                inviter=sharing.public_user(inviter),
                status=inv.status,
                created_at=inv.created_at,
            )
        )
    return out


@router.get("/{community_id}", response_model=list[CommunityMemberRead])
def list_members(
    community_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[CommunityMemberRead]:
    sharing.require_member(db, community_id, user.id)
    members = db.scalars(
        select(CommunityMember).where(CommunityMember.community_id == community_id)
    ).all()
    out: list[CommunityMemberRead] = []
    for m in members:
        member_user = db.get(User, m.user_id)
        if member_user is not None:
            out.append(
                CommunityMemberRead(
                    user=sharing.public_user(member_user),
                    role=m.role,
                    joined_at=m.joined_at,
                )
            )
    return out


@router.post("/{community_id}/invite", status_code=201)
def invite(
    community_id: int,
    body: InviteCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    # Must be a member to invite, and may only invite an EXISTING accepted friend.
    sharing.require_member(db, community_id, user.id)
    if not sharing.are_friends(db, user.id, body.invitee_id):
        raise sharing.Forbidden("You can only invite accepted friends.")
    if sharing.is_member(db, community_id, body.invitee_id):
        raise sharing.Conflict("That user is already a member.")

    existing = db.scalar(
        select(CommunityInvite).where(
            CommunityInvite.community_id == community_id,
            CommunityInvite.invitee_id == body.invitee_id,
            CommunityInvite.status == "pending",
        )
    )
    if existing is not None:
        raise sharing.Conflict("A pending invite already exists.")

    db.add(
        CommunityInvite(
            community_id=community_id,
            inviter_id=user.id,
            invitee_id=body.invitee_id,
            status="pending",
        )
    )
    db.commit()
    return {"status": "pending"}


@router.post("/invite/{invite_id}/accept", response_model=CommunityRead)
def accept_invite(
    invite_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CommunityRead:
    invite = db.get(CommunityInvite, invite_id)
    if invite is None or invite.invitee_id != user.id or invite.status != "pending":
        raise sharing.NotFound("No pending invite.")

    # Atomic cap enforcement happens here; raises Conflict if the community is full.
    sharing.add_member_atomically(db, invite.community_id, user.id, role="member")
    invite.status = "accepted"
    db.commit()

    community = db.get(Community, invite.community_id)
    return sharing.community_read(db, community)
