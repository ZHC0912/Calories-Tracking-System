"""Daily reports are COMPUTED on demand, not stored.

services/report.py::build_daily_report aggregates a user's FoodEntry and
ExerciseEntry rows for a calendar day (in their timezone) into a DailyReport.
There is intentionally no table here.

A snapshot table may be added in Phase 3 to freeze a report for sharing on the
social feed; until then this module is a deliberate placeholder so the design
intent is explicit.
"""
