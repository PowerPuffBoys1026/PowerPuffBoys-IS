# Feature: Mobile-Ready Backend

> Feature record for the `feature/mobile-ready-backend` branch. This work prepares
> the API and database for phone clients; it does **not** add Flutter screens or
> change the UI/UX.

| Item | Value |
|---|---|
| Branch | `feature/mobile-ready-backend` |
| Based on | `fix/v2-ui-ux-followups` at `5c16f39` |
| Intended PR base | `fix/v2-ui-ux-followups` (**not** `main`, which is behind) |
| Verification | `npm test` 38/38, `npm run smoke` 64/64 |
| Scope | Backend, database, configuration, docs and Android connectivity manifest |
| Recorded | 2026-11-18 |

---

## 1. Why this work exists

Mobile is the everyday target in the ClassMate proposal, but the existing setup
was desktop-first:

- `localhost` in the Flutter client points at the phone itself, not the PC
  running the API.
- Release Android builds had no `INTERNET` permission and blocked cleartext LAN
  traffic.
- The stored procedures had no automated test coverage and the API still
  duplicated some read/status logic.
- Phone clients had no explicit token-expiry signal and no public endpoint for
  non-secret configuration values.

This branch makes the backend predictable and testable for mobile clients while
leaving screen work to the UI/Flutter developer.

---

## 2. Commits in this feature

| Commit | Title | Purpose |
|---|---|---|
| `8046307` | `feat: make backend and database ready for mobile clients` | LAN helper script, Android manifest permission/cleartext config, mobile docs, migration 005 and routine tests |
| `aeb237b` | `refactor(api): use tested stored routines for read and status queries` | Routes attendance summary, dashboard and work status through the tested database routines |
| `6ca878b` | `feat(api): add mobile token expiry, client config and tunable limits` | `tokenExpiresAt`, `TOKEN_EXPIRED`, `/api/client-config`, request/auth limits and env knobs |
| `71d6f6e` | `chore(db): add mobile indexes, integrity tests and rollback guide` | Migration 006, data-integrity tests and backup/rollback documentation |

All four commits are pushed to `origin/feature/mobile-ready-backend`.

---

## 3. What changed

### 3.1 Mobile connectivity

- Added `npm run mobile:config` (`server/scripts/mobile-config.js`). It prefers a
  physical Wi-Fi adapter over Hyper-V/virtual adapters and prints:
  - the PC's LAN IPv4 address,
  - the exact `flutter run ... --dart-define=API_BASE_URL=...` command,
  - the phone health-check URL,
  - the Windows Firewall and CORS values needed for the LAN.
- Added `INTERNET` permission and `android:usesCleartextTraffic="true"` to
  `client/android/app/src/main/AndroidManifest.xml` for LAN development.
- Documented phone testing in [`run-and-stop.md`](run-and-stop.md) and
  [`../server/README.md`](../server/README.md).

Native Android/iOS apps are not affected by CORS. Flutter Web opened from a
phone is: add `http://<pc-ip>:8080` to `CORS_ORIGIN` and restart the API.

### 3.2 Stored procedures wired into the API

Migration `server/migrations/005_stored_procedures.sql` was copied from the
database branch and is covered by `server/test/stored-procedures.test.js`.

| Routine | API consumer | Notes |
|---|---|---|
| `get_attendance_summary` | `GET /api/attendance/summary` | Preserves the previous attendance rate and warning math |
| `get_dashboard_classes` | `GET /api/dashboard/today` | Columns are aliased back to `id`/`type` for existing views |
| `get_due_soon_works` | `GET /api/dashboard/today` | Uses `APP_TIMEZONE` for the rolling 7-day window |
| `set_work_status` | `PATCH /api/works/:id/status` | PostgreSQL `P0002` is translated to a `404` |
| `mark_attendance` | Not wired to an endpoint | The API must keep returning `409` for duplicate attendance instead of silently upserting |

The routines enforce ownership checks in the database as well as the API.

### 3.3 Mobile-facing API contract

- `POST /api/auth/register` and `POST /api/auth/login` now also return
  `tokenExpiresAt`.
- An expired token returns `401` with
  `error.code: TOKEN_EXPIRED`; other invalid tokens stay generic.
- New public endpoint `GET /api/client-config` returns non-secret thresholds,
  enum values and payload limits so the client does not hard-code them.
- Fixed limits: 1 MB JSON body, 20 MB attachment, and page size 1–100.
- Added tunable environment settings for mobile networks:

| Variable | Default | Purpose |
|---|---|---|
| `REQUEST_TIMEOUT_MS` | `30000` | Maximum time for a single phone request |
| `AUTH_RATE_LIMIT_MAX` | `20` | Login/register attempts per IP per window |
| `AUTH_RATE_LIMIT_WINDOW_MS` | `900000` | Auth rate-limit window in milliseconds |

Several phones behind one NAT share a public IP, so raise
`AUTH_RATE_LIMIT_MAX` during a demo if needed.

### 3.4 Database quality

- Added `server/migrations/006_mobile_query_indexes.sql`:
  - `idx_attendance_date` for date-range attendance filters,
  - `idx_slots_day_of_week` for day/week timetable views.
- Added `server/test/data-integrity.test.js` for constraints, uniqueness,
  cascades and migration application.
- Expanded [`database.md`](database.md) with migrations, integrity rules,
  backup/restore commands, rollback policy and mobile notes.

Migrations are forward-only. Take a backup before manual schema changes; see
[`database.md` §4–5](database.md) for the exact commands and rollback options.

---

## 4. How to verify this feature

Run from `server/`:

```powershell
npm ci
npm test        # 38/38 — includes routine and data-integrity tests
npm run smoke   # 64/64 — end-to-end against an isolated DB/port
npm run mobile:config
```

Then, with the API running and a phone on the same Wi-Fi:

```powershell
cd ..\client
flutter devices
flutter run -d <device-id> --dart-define=API_BASE_URL=http://<pc-ip>:3000/api
```

Confirm from the phone browser that `http://<pc-ip>:3000/api/health` succeeds.
On the emulator, use `http://10.0.2.2:3000/api` instead.

---

## 5. Review and handoff notes

- The PR should target `fix/v2-ui-ux-followups`; `main` is eight commits behind
  and would drop the v2 work.
- No secrets, `.env` files or API keys were committed.
- There are no UI/screen changes in this feature.
- A teammate review is still required before merge.

## 6. Known limitations / follow-ups

- Local notifications and reminders are not implemented;
  `flutter_local_notifications` is not in `client/pubspec.yaml`.
- iOS builds require macOS/Xcode and could not be verified on Windows.
- Cleartext LAN HTTP is development-only. Use HTTPS before any real deployment.
- `mark_attendance` remains a direct-database routine by design; duplicate
  attendance submissions must continue to return `409` from the API.
