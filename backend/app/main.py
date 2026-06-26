"""FastAPI entry point.

Run from backend/:  uvicorn app.main:app --reload
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from .api import (
    analyze,
    auth,
    community,
    feed,
    friends,
    images,
    log,
    profile,
    report,
)
from .services.sharing import ShareError

app = FastAPI(
    title="Calorie Tracking API",
    description=(
        "Backend brain for the calorie-tracking system. All logic lives here "
        "behind REST endpoints; clients (Flutter app, future WhatsApp webhook) "
        "stay thin."
    ),
    version="0.3.0",
)

# Phase 1: stateless analysis.
app.include_router(analyze.router)
# Phase 2: users, profile/target, logging, daily reports, image serving.
app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(log.router)
app.include_router(report.router)
app.include_router(images.router)
# Phase 3: friends, communities, share feed, reactions.
app.include_router(friends.router)
app.include_router(community.router)
app.include_router(feed.router)


@app.exception_handler(ShareError)
async def _share_error_handler(request: Request, exc: ShareError) -> JSONResponse:
    """Map social-layer authorization/validation errors to their HTTP status."""
    return JSONResponse(status_code=exc.status_code, content={"detail": str(exc)})


@app.get("/health", tags=["meta"])
def health() -> dict:
    return {"status": "ok"}
