# Calories-Tracking-System

Photograph a meal, get dishes + grams + calories, log it against a personal
target — with a social layer for friendly accountability later.

| Directory | What it is |
| --- | --- |
| `backend/` | FastAPI backend — **all** logic lives here behind REST endpoints. See `backend/README.md`. |
| `model/` | ML training ground (train → export → version → swap). See `model/README.md`. |
| `app/` | Flutter client (Phase 3) — thin, endpoints only. Empty for now. |

**Status: Phase 1** — core analysis engine (`POST /analyze`) with a stub
model. Database, auth, logging/reports (Phase 2) and the social layer +
Flutter app (Phase 3) come later; their files exist as placeholders.
