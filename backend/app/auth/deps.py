"""FastAPI dependency that resolves the current user from a bearer JWT.

Business-logic endpoints depend on get_current_user; they never parse tokens or
touch the auth secret themselves.
"""

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from ..db import get_db
from ..models.user import User
from .security import decode_token

_bearer = HTTPBearer(auto_error=True)

_UNAUTHORIZED = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Invalid or expired credentials.",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    try:
        user_id = decode_token(credentials.credentials)
    except (jwt.PyJWTError, ValueError, KeyError):
        raise _UNAUTHORIZED

    user = db.get(User, user_id)
    if user is None:
        raise _UNAUTHORIZED
    return user
