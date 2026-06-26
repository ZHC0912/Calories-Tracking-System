# Calories — Flutter app

Thin client for the calorie-tracking backend. **The backend is the brain**; this
app only captures a meal photo, shows what the backend recognized, lets the user
confirm/correct it, logs it, and shows today's totals. All calorie math and the
daily target live on the server.

## App Phase 1 (this code)

The foundation plus the core loop: **capture → analyze → confirm → log → today**.

- **Auth** — register / login against the backend's JWT endpoints. The token is
  stored in the OS keychain/keystore via `flutter_secure_storage` (never
  SharedPreferences) and attached as `Authorization: Bearer <token>`.
- **Capture** (`/analyze`) — take or pick a meal photo, add an optional caption
  (e.g. `nasi lemak 250g`), and analyze.
- **Confirm** (the hero screen) — for each recognized item: correct the dish
  (low-confidence items lead with an "Is this …?" prompt), choose a portion
  (precise **grams** or a quick **Small / Medium / Large** bucket), and see an
  honesty tag (`from 250 g`, `Medium portion`, `estimated`) plus a calorie
  preview. Items can be removed; multi-item plates are supported.
- **Log** (`/log/food`) — sends the confirmed items (+ the photo). The backend
  recomputes the authoritative calories; the client never sends nutrient numbers.
- **Today** (`/report/today`) — total intake and the meals logged so far. The
  daily target/remaining appear only when the profile provides them; otherwise a
  gentle "set up your profile" hint (profile is App Phase 2).

## App Phase 2 (this code)

Profiles, targets, exercise, history, real thumbnails, and proper navigation.

- **Onboarding** — first-run guided setup (weight/height/age/sex/activity/goal/
  timezone, default `Asia/Kuala_Lumpur`) via `PUT /profile`, then shows the
  backend-computed daily target + BMI. **Skippable** — the core loop already
  works without a profile; finishing it unlocks target/remaining on Today.
- **Profile tab** — view/edit all stats, see `ProfileSummary` (BMI + muscle-vs-fat
  caveat, daily target, activity guidance, the not-medical-advice note), a
  plain-language **training-consent** toggle (`allow_training_use`), and logout.
- **Exercise tab** — log two ways, mirroring `POST /log/exercise`: activity +
  minutes (backend computes kcal via METs + your weight) or direct kcal. The
  time-based activity list matches the backend's MET table.
- **Today** — now shows intake, burned, **net**, target, remaining, and macro
  totals (all backend-computed; only fields present are shown).
- **History tab** — pick any past day (`GET /report/{date}`) and view it
  read-only.
- **Navigation** — bottom nav (Today / Exercise / History / Profile) with a
  center **capture** FAB. Social stays out of nav (App Phase 3).
- **Thumbnails** — meal photos load from the authenticated `GET /images/{ref}`
  endpoint (bearer token attached), with a graceful placeholder fallback.

The app **never computes** BMI or targets — it only displays the backend's
values, including the disclaimers.

## App Phase 3 (this code)

The social finale — an encouragement tool, not a chat app. **No free text on any
social surface, reactions are a fixed emoji set, and sharing is always an
explicit tap.**

- **Friends** (Friends tab) — search people by email (`PublicUser`, safe fields
  only) and add them. The backend auto-accepts a mutual request, so "Add" both
  sends and (when mutual) accepts. Tap a friend to edit their **share defaults**.
- **Communities** (Communities tab) — create a community, see the ones you're in,
  and open a detail view (members-only) to **invite a friend** (friend-gated,
  cap 10 — "not friends"/"full" errors surface inline) or open its feed. Incoming
  invites live behind the mailbox icon with a badge.
- **Share sheet** — from the **Share** action on Today. `GET /share/preview`
  pre-ticks the *parts* from your friend defaults; target communities start
  unselected so a share is always deliberate. Body-derived **target/remaining**
  default OFF and are labeled "more revealing". Nothing sends until you tap
  **Share** (`POST /share`).
- **Feed** — a community's chronological snapshots showing only the shared parts
  (consistency signals, net calories, macros, food photos via the image
  endpoint, target if included). React with 👍/💪/🔥/👏 — one per post,
  changeable, removable. No comments.
- **Navigation** — a **Community** tab joins the bottom nav.

Profile stats (weight/height/age/BMI) are **never** shown on any social surface,
and there are no leaderboards or rankings.

## Set the backend URL

Edit the single constant in `lib/config.dart` to match where you run the app:

| Run target          | `AppConfig.baseUrl`                |
| ------------------- | --------------------------------- |
| Android emulator    | `http://10.0.2.2:8000` (default)  |
| iOS simulator       | `http://localhost:8000`           |
| Physical device     | `http://<dev-machine-LAN-IP>:8000` (phone + computer on the same Wi-Fi) |

Cleartext HTTP to these dev hosts is already allowed (Android
`usesCleartextTraffic`, iOS `NSAllowsLocalNetworking`). Switch to HTTPS for any
real deployment.

## Run

1. Start the backend (from `../backend`):

   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

   `--host 0.0.0.0` lets the emulator/device reach it. The Android emulator sees
   the host machine at `10.0.2.2`.

2. Run the app (from `app/`):

   ```bash
   flutter pub get
   flutter run
   ```

## Develop

```bash
flutter analyze   # static analysis (lints clean)
flutter test      # model/format/widget smoke tests
```

## Structure

```
lib/
├── config.dart          # base URL + constants (change the URL here)
├── theme/app_theme.dart # warm, photo-first visual direction
├── api/                 # dio client (+ token interceptor, error mapping) + per-endpoint wrappers
├── models/              # Dart mirrors of the backend schemas
├── state/               # Riverpod providers (auth, analyze draft, today report)
├── screens/             # auth, shell (bottom nav), home, capture+confirm, onboarding, profile, exercise, history, social (friends/communities/feed/share)
└── widgets/             # shared UI (honesty tag, error banner, meal thumbnail, form fields)
```
