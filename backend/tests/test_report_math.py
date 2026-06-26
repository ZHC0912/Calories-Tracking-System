"""Daily-report math: timezone day-bucketing and net/remaining computation."""

from datetime import date, datetime

from app.services.report import utc_window


def test_utc_window_for_kuala_lumpur():
    # KL is UTC+8, so its local 14 Jun runs 13 Jun 16:00 -> 14 Jun 16:00 UTC.
    start, end = utc_window(date(2026, 6, 14), "Asia/Kuala_Lumpur")
    assert start == datetime(2026, 6, 13, 16, 0)
    assert end == datetime(2026, 6, 14, 16, 0)


def test_utc_window_for_utc_is_midnight_to_midnight():
    start, end = utc_window(date(2026, 6, 14), "UTC")
    assert start == datetime(2026, 6, 14, 0, 0)
    assert end == datetime(2026, 6, 15, 0, 0)


def test_window_is_24h_wide():
    start, end = utc_window(date(2026, 1, 1), "America/New_York")
    assert (end - start).total_seconds() == 24 * 3600
