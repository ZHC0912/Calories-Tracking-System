# Calorie Tracking — Backend

The **backend is the brain**: dish recognition, portion resolution, nutrient
lookup, and (in later phases) targets, logging, and sharing all live here
behind REST endpoints. Clients — the Flutter app, and possibly a WhatsApp
webhook later — are thin and only call these endpoints.

## Phase status

- **Phase 1: core analysis engine.** `POST /analyze` turns an image + optional
  caption into foods with grams and calories. Stateless, stub model, no auth.
- **Phase 2 (this code): per-user system.** PostgreSQL (SQLAlchemy + Alembic),
  self-rolled JWT auth, profiles + calorie targets (Mifflin-St Jeor with a safe
  floor), meal/exercise logging that reuses the Phase 1 pipeline, and a daily
  intake-vs-target report computed in the user's timezone.
- **Phase 3 (this code): social supervision layer.** Friends, invite-only
  friend-gated communities (capped at 10), explicit sharing of daily-report
  snapshots into communities, and fixed-emoji reactions. No chat, no free text,
  no leaderboards.

## Setup

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows  (Linux/macOS: source .venv/bin/activate)
pip install -r requirements.txt
copy .env.example .env        # then fill in values (Linux/macOS: cp)
```

`.env` variables:

| Variable | Meaning |
| --- | --- |
| `USDA_API_KEY` | FoodData Central API key (free at https://fdc.nal.usda.gov/api-key-signup). Optional — without it, lookups serve from `data/usda_cache.json` only. |
| `STORAGE_DIR` | Where the local storage backend writes files (dev). |
| `MODEL_BACKEND` | `stub` for now; real model backends register in `core/model_backend.py`. |
| `USDA_CACHE_PATH` | Nutrient cache file. |
| `DATABASE_URL` | SQLAlchemy URL. Defaults to a local SQLite file; use `postgresql+psycopg2://user:pass@host:5432/db` for Postgres. |
| `JWT_SECRET` | Secret for signing JWTs. **Set a long random value** for any real deploy (`python -c "import secrets; print(secrets.token_urlsafe(48))"`). |
| `JWT_EXPIRE_MIN` | Access-token lifetime in minutes (default 60). |

## Database & migrations

Schema is managed by Alembic. After setting `DATABASE_URL`, create the tables:

```bash
alembic upgrade head        # apply migrations (creates users + log tables)
```

The default `DATABASE_URL` is SQLite, so this works with no DB server. For
Postgres, point `DATABASE_URL` at your instance and run the same command.
After changing any model in `app/models/`, generate a new migration:

```bash
alembic revision --autogenerate -m "describe the change"
alembic upgrade head
```

## Run

```bash
alembic upgrade head          # once, to create the schema
uvicorn app.main:app --reload
```

Then open http://127.0.0.1:8000/docs.

### Auth flow

1. `POST /auth/register` `{ "email", "password" }` → `{ access_token }`.
2. `POST /auth/login` with the same credentials → `{ access_token }`.
3. Send `Authorization: Bearer <token>` on the protected routes:
   - `GET/PUT /profile` — body stats (kg/cm), goal, timezone, training consent;
     GET returns computed BMI + daily calorie target (estimates, not advice).
   - `POST /log/food` (multipart: `items` JSON + optional `image`) and
     `POST /log/exercise` — calories are recomputed server-side via the Phase 1
     core, never trusted from the client.
   - `GET /report/today` and `GET /report/{YYYY-MM-DD}` — intake vs target for
     that local-calendar day, exercise deducted.
   - `GET /images/{ref}` — serves a stored meal image. A caller may fetch it if
     EITHER (a) `ref` is the `image_path` on one of their own food entries, OR
     (b) `ref` appears in a feed-post snapshot shared into a community they
     belong to. Non-allowed/missing refs and traversal attempts all return 404,
     so nothing about other users' images leaks. Both checks live in
     `api/images.py::user_can_view_image`.

Meal images are EXIF-stripped before storage. If a user opts in
(`allow_training_use`), an EXIF-stripped, dish-labeled copy is also kept in a
separate `training` namespace for future model work. Stored images are read back
only through the authenticated, owner-scoped `GET /images/{ref}` route — the DB
still stores just the path string, never bytes.

`POST /analyze` (Phase 1) stays stateless and needs no auth.

### Social layer (Phase 3)

A **supervision/encouragement** tool, not a chat app and not a competition. The
design rules are enforced server-side, not just by convention:

- **No free text anywhere.** There is no message/comment/caption column. The
  only user-authored signal is a **reaction from a fixed emoji set** (👍 💪 🔥 👏);
  anything else is rejected.
- **Sharing is always explicit.** `GET /share/preview` only builds a share sheet
  (pre-ticking recipients/parts from your saved defaults) — it persists nothing.
  `POST /share` is the *only* path that writes to a feed. "Auto-share" means
  pre-selected defaults, never an automatic send.
- **Friend-gated, capped communities.** You can only invite users you are already
  friends with, and only into communities you belong to. Membership is hard-capped
  at **10**, enforced atomically on join.
- **Minimum-share / privacy.** A shared report is a bundle of toggleable parts.
  Body-derived parts (calorie **target**, remaining-vs-target) default **OFF** and
  appear only when explicitly included. No social route ever returns another
  user's raw profile stats (weight/height/age/BMI) — users are exposed only as
  `{id, handle, display_name}`.
- **Healthy framing.** Feeds are chronological; there are no leaderboards and no
  ranking by calories. Snapshots surface consistency signals (logged today, item
  counts).

Endpoints (all require a bearer token):

| Area | Routes |
| --- | --- |
| Friends | `POST /friends/request`, `POST /friends/accept`, `GET /friends`, `GET /friends/search?handle=` |
| Communities | `POST /community`, `GET /community`, `GET /community/{id}` (members only), `POST /community/{id}/invite` (friend-gated), `GET /community/invites`, `POST /community/invite/{id}/accept` (cap enforced) |
| Sharing & feed | `GET /share/preview?date=`, `POST /share`, `GET /feed/{community_id}`, `POST /feed/{post_id}/react`, `DELETE /feed/{post_id}/react` |
| Share defaults | `GET /share/defaults/{friend_id}`, `PUT /share/defaults/{friend_id}` |

Shared report content is built by reusing `services/report.py` (Phase 2) and then
**snapshotted** at share time — feed posts never recompute, and store only the
parts that were actually shared.

## Tests

```bash
pytest
```

Tests are fully offline — they use the stub model and seeded caches, never
the live USDA API.

## Architecture notes

- `app/core/` is **pure logic**: no DB, auth, or web-framework imports. The
  API layer in `app/api/` is a thin wrapper around it. Phase 2 business logic
  lives in `app/services/` (pure target math, report aggregation) and `app/api/`.
- **Auth is isolated** in `app/auth/` (hashing + JWT only there), so it could be
  swapped for OAuth/Firebase without touching business logic. Identity is the
  internal user `id`, not the email — a future channel (e.g. WhatsApp) can add
  its own handle without reworking the schema.
- **The social layer (Phase 3)** keeps all its rules in `app/services/sharing.py`
  (friendship/membership checks, the atomic member cap, snapshot building, the
  single explicit-share path); the routers in `app/api/{friends,community,feed}.py`
  stay thin. Social tables in `app/models/social.py` carry FK columns but no
  relationships back onto `User`, so Phases 1–2 models are untouched.
- The ML model sits behind `core/model_backend.py::ModelBackend` and is
  selected via config, so retrained model files (versioned under
  `../model/versions/`) can be hot-swapped without touching other code.
- File storage sits behind `storage/base.py::StorageBackend` (local disk in
  dev, cloud bucket later). The DB only ever stores the returned path string.
- Adding a supported dish = adding one entry in `app/core/dishes.py`.
