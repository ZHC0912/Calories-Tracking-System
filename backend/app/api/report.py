"""Daily report endpoints (auth required): intake vs target, exercise deducted.

The report is computed on demand (services/report.py) from the user's logged
entries, bucketed into their local calendar day. This is the same DailyReport
object Phase 3 will selectively share on the social feed.
"""

from datetime import date as date_type
from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..auth.deps import get_current_user
from ..db import get_db
from ..models.user import User
from ..schemas.report import DailyReport
from ..services.report import build_daily_report

router = APIRouter(prefix="/report", tags=["report"])


@router.get("/today", response_model=DailyReport)
def report_today(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DailyReport:
    tz = ZoneInfo(user.timezone or "UTC")
    today = datetime.now(tz).date()
    return build_daily_report(db, user, today)


@router.get("/{day}", response_model=DailyReport)
def report_for_day(
    day: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DailyReport:
    try:
        parsed = date_type.fromisoformat(day)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Date must be ISO format YYYY-MM-DD.",
        )
    return build_daily_report(db, user, parsed)
