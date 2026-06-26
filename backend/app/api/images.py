"""Authenticated image serving.

Returns a stored meal image's bytes, but only to a user who is allowed to see
it. The authorization check lives in one helper so App Phase 3 can EXTEND it to
"...or an image shared into a community I belong to" without touching the route
or leaking anything in the meantime.

Security model:
- Auth required (bearer token).
- A user may fetch an image only when its storage path is the `image_path` on
  one of their OWN food entries. A non-owned or non-existent ref both yield 404,
  so the endpoint never reveals whether an image exists.
- Path traversal can't escape the storage root: a crafted ref won't match any of
  the user's stored paths (404), and the storage backend rejects it as a second
  line of defense.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth.deps import get_current_user
from ..config import get_settings
from ..db import get_db
from ..models.log import FoodEntry
from ..models.social import CommunityMember, FeedPost
from ..models.user import User
from ..storage.local import LocalDiskStorage

router = APIRouter(prefix="/images", tags=["images"])

_CONTENT_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}


def _owns_image(db: Session, user_id: int, ref: str) -> bool:
    """True iff ``ref`` is the image_path on one of the user's own food entries."""
    return (
        db.scalar(
            select(FoodEntry.id).where(
                FoodEntry.user_id == user_id,
                FoodEntry.image_path == ref,
            )
        )
        is not None
    )


def _shared_into_my_community(db: Session, user_id: int, ref: str) -> bool:
    """True iff ``ref`` appears in a FeedPost snapshot shared into a community
    the user belongs to.

    Snapshots store shared photos under ``payload["food_images"]`` as
    ``[{"dish", "image_path"}]`` (see services/sharing.build_snapshot). We scan
    only posts in the user's own communities, so this never grants access to a
    non-member. Done in Python to stay portable across SQLite and Postgres (no
    JSON-path operators); community feeds are small.
    """
    posts = db.scalars(
        select(FeedPost)
        .join(CommunityMember, CommunityMember.community_id == FeedPost.community_id)
        .where(CommunityMember.user_id == user_id)
    ).all()
    for post in posts:
        payload = post.payload if isinstance(post.payload, dict) else {}
        for image in payload.get("food_images") or []:
            if isinstance(image, dict) and image.get("image_path") == ref:
                return True
    return False


def user_can_view_image(db: Session, user: User, ref: str) -> bool:
    """Authorize a read of image ``ref``. A user may view it if EITHER:

    (a) it's on one of their OWN food entries, OR
    (b) it was shared (in a FeedPost snapshot) into a community they belong to.

    Anything else is denied (the caller returns 404). Not broadened beyond these
    two cases.
    """
    return _owns_image(db, user.id, ref) or _shared_into_my_community(
        db, user.id, ref
    )


@router.get("/{ref:path}")
def get_image(
    ref: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    if not user_can_view_image(db, user, ref):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Image not found."
        )

    storage = LocalDiskStorage(get_settings().storage_dir)
    try:
        data = storage.get(ref)
    except (FileNotFoundError, ValueError):
        # FileNotFoundError: row exists but file is gone.
        # ValueError: storage backend rejected a traversal attempt.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Image not found."
        )

    suffix = ref[ref.rfind(".") :].lower() if "." in ref else ""
    media_type = _CONTENT_TYPES.get(suffix, "application/octet-stream")
    return Response(content=data, media_type=media_type)
