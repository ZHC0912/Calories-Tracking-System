"""Auth endpoints: register and login. Returns a JWT access token.

Self-rolled, isolated behind auth/security.py. Plaintext passwords are never
stored, returned, or logged. Identity is the user's stable id; email is just the
current login handle (a future channel like WhatsApp can add its own).
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from ..auth.security import create_access_token, hash_password, verify_password
from ..db import get_db
from ..models.user import User
from ..schemas.user import LoginRequest, RegisterRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = body.email.lower()
    exists = db.scalar(select(User).where(User.email == email))
    if exists is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="Email already registered."
        )

    username = body.username.strip() if body.username else None
    if username:
        clash = db.scalar(
            select(User).where(func.lower(User.username) == username.lower())
        )
        if clash is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Username already taken.",
            )

    user = User(
        email=email,
        username=username or None,  # treat empty/whitespace as unset
        password_hash=hash_password(body.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return TokenResponse(access_token=create_access_token(user.id))


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    # Accept a username (case-insensitive) or an email as the login handle.
    handle = (body.username or body.email or "").strip()
    user = None
    if handle:
        user = db.scalar(
            select(User).where(
                or_(
                    func.lower(User.username) == handle.lower(),
                    User.email == handle.lower(),
                )
            )
        )
    # A missing user or wrong password yields the same generic 401 so we don't
    # reveal which usernames/emails exist.
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password.",
        )
    return TokenResponse(access_token=create_access_token(user.id))
