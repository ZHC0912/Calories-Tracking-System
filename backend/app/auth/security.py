"""Password hashing (bcrypt) and JWT create/verify.

This is the ONLY module that touches crypto, so the whole auth mechanism could
be swapped (OAuth, Firebase) without touching business logic. Secrets and
expiry come from config (JWT_SECRET, JWT_EXPIRE_MIN) — never hardcoded.
Plaintext passwords are never stored, returned, or logged.
"""

from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from ..config import get_settings

_ALGORITHM = "HS256"

# bcrypt hashes at most the first 72 bytes of a password. Pre-hashing would be
# the way to lift that; we instead reject over-long input so behaviour is
# explicit rather than silently truncated.
_MAX_PASSWORD_BYTES = 72


def hash_password(plain: str) -> str:
    """Hash a plaintext password. Returns the bcrypt hash string to persist."""
    pw = plain.encode("utf-8")
    if len(pw) > _MAX_PASSWORD_BYTES:
        raise ValueError("Password must be at most 72 bytes.")
    return bcrypt.hashpw(pw, bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Constant-time check of a plaintext password against a stored hash."""
    pw = plain.encode("utf-8")
    if len(pw) > _MAX_PASSWORD_BYTES:
        return False
    try:
        return bcrypt.checkpw(pw, hashed.encode("utf-8"))
    except ValueError:
        return False


def create_access_token(user_id: int) -> str:
    """Mint a signed JWT whose subject is the user's stable internal id."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "iat": now,
        "exp": now + timedelta(minutes=settings.jwt_expire_min),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=_ALGORITHM)


def decode_token(token: str) -> int:
    """Validate a JWT and return its user id. Raises jwt.PyJWTError if invalid."""
    settings = get_settings()
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[_ALGORITHM])
    return int(payload["sub"])
