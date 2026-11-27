# Mobile-Ready Backend — Integration Record for the Main System

> This record documents the `feature/mobile-ready-backend` milestone being folded
> into the main working branch of `PowerPuffBoys-IS`. It complements — and does
> not replace — the feature record in
> [`mobile-ready-backend.md`](mobile-ready-backend.md).

| Item | Value |
|---|---|
| Main worktree | `PowerPuffBoys-IS/` on `fix/v2-ui-ux-followups` |
| Source worktree | `PowerPuffBoys-IS-mobile-backend/` on `feature/mobile-ready-backend` |
| Base before integration | `5c16f39` |
| Integrated tip | `5c45180` |
| Integration method | `git merge --ff-only feature/mobile-ready-backend` (fast-forward, **0 conflicts**) |
| Date | 2026-11-27 |
| Verification | `npm test` **38/38**, `npm run smoke` **64/64** |

---

## 1. What this milestone means for the whole system

ClassMate is one product with three surfaces that all share a single backend:

| Layer | Technology | Role |
|---|---|---|
| Client | Flutter (Web, Windows, Android, iOS targets) | Screens for login, dashboard, schedule, attendance, school works, subjects, notes |
| Web app | v2 UI served by the API from `server/public/` | Study stats, grades/GPA, attachments, recycle bin, profile settings |
| API + data | Node/Express + PostgreSQL | JWT auth, REST endpoints, stored routines, all persisted data |

The mobile milestone is an **infrastructure and contract upgrade** for the shared
API/database layer. It makes the backend predictable and testable when the
everyday target is a phone, while deliberately leaving the Flutter screens and
the v2 web UI untouched. In other words: no new features were added to the UI;
the existing app(s) keep working, but the platform underneath them is now ready
for phone clients.

---

## 2. Commits integrated

| Commit | Title | Contribution to the system |
|---|---|---|
| `8046307` | `feat: make backend and database ready for mobile clients` | LAN helper script, Android connectivity manifest, migration 005, routine tests, mobile docs |
| `aeb237b` | `refactor(api): use tested stored routines for read and status queries` | Attendance summary, dashboard and work status now use tested DB routines |
| `6ca878b` | `feat(api): add mobile token expiry, client config and tunable limits` | `tokenExpiresAt`, `TOKEN_EXPIRED`, `/api/client-config`, payload/rate limits, env knobs |
| `71d6f6e` | `chore(db): add mobile indexes, integrity tests and rollback guide` | Migration 006, data-integrity tests, backup/rollback documentation |
| `5c45180` | `docs: document mobile-ready backend feature` | Feature record and README pointers |

---

## 3. What is actually inside the merged milestone

### 3.1 Phone connectivity

- `server/scripts/mobile-config.js` backs `npm run mobile:config`. It discovers
  private LAN IPv4 addresses, prefers a real Wi-Fi/Ethernet adapter over virtual
  ones (Docker/Hyper-V/WSL), and prints:
  - the PC's LAN address,
  - the exact `flutter run --dart-define=API_BASE_URL=...` command,
  - the phone health-check URL,
  - the `CORS_ORIGIN` entry needed for Flutter Web on a phone,
  - the Windows Firewall command for port 3000.
- `client/android/app/src/main/AndroidManifest.xml` now declares `INTERNET` and
  `android:usesCleartextTraffic="true"` for LAN development.
- `docs/run-and-stop.md` and `server/README.md` explain phone testing and what to
  change for Web-vs-native CORS (native apps are not subject to CORS).

### 3.2 Stored routines become the single source of truth

Migration 005 (`server/migrations/005_stored_procedures.sql`, 353 lines) is now a
tracked part of the main system and is covered by
`server/test/stored-procedures.test.js`:

| Routine | API consumer | Behaviour preserved |
|---|---|---|
| `get_attendance_summary` | `GET /api/attendance/summary` | Same attendance rate and warning math |
| `get_dashboard_classes` | `GET /api/dashboard/today` | Columns aliased back to the existing view shape |
| `get_due_soon_works` | `GET /api/dashboard/today` | Rolling 7-day window uses `APP_TIMEZONE` |
| `set_work_status` | `PATCH /api/works/:id/status` | SQLSTATE `P0002` becomes a `404` |
| `mark_attendance` | Not wired to an endpoint (by design) | Duplicate attendance must still return `409` from the API |

Ownership checks are enforced in the database as well as in the API.

### 3.3 Mobile-facing API contract

- `POST /api/auth/register` and `POST /api/auth/login` also return
  `tokenExpiresAt`, so a phone can schedule a silent re-login.
- An expired token returns `401` with `error.code: TOKEN_EXPIRED`; other invalid
  tokens remain generic.
- New public endpoint `GET /api/client-config` returns non-secret values
  (timezone, attendance threshold, JWT lifetime, payload limits, enum lists) so
  the client does not hard-code them.
- Fixed limits: 1 MB JSON body, 20 MB attachment, page size 1–100.
- New `.env` knobs for mobile networks:

| Variable | Default | Purpose |
|---|---|---|
| `REQUEST_TIMEOUT_MS` | `30000` | Bound a single slow phone request |
| `AUTH_RATE_LIMIT_MAX` | `20` | Login/register attempts per IP per window |
| `AUTH_RATE_LIMIT_WINDOW_MS` | `900000` | Auth rate-limit window |

Several phones behind one NAT share an IP; raise `AUTH_RATE_LIMIT_MAX` for a demo
if needed. `server/.env.example` documents all three, but existing local `.env`
files are not modified — copy the new keys across only if you want to tune them.

### 3.4 Database quality and safety

- Migration 006 (`006_mobile_query_indexes.sql`) adds `idx_attendance_date` and
  `idx_slots_day_of_week` for phone-side date/day filters.
- `server/test/data-integrity.test.js` verifies constraints, per-user
  uniqueness, cascades and that every migration applies from scratch.
- `docs/database.md` is now part of the main docs: migration map, integrity
  rules, `pg_dump`/`pg_restore` backup commands, forward-only rollback policy and
  mobile notes.

### 3.5 Tests and docs added to the main tree

New tracked files now present in `PowerPuffBoys-IS/`:

```text
docs/database.md
docs/mobile-ready-backend.md
docs/mobile-backend-migration.md        <- this record
server/migrations/005_stored_procedures.sql
server/migrations/006_mobile_query_indexes.sql
server/scripts/mobile-config.js
server/src/controllers/client-config.controller.js
server/src/routes/client-config.js
server/test/data-integrity.test.js
server/test/mobile-config.test.js
server/test/stored-procedures.test.js
```

---

## 4. How existing work was protected

The feature branch descends **directly** from the main branch tip (`5c16f39`), so
the merge is a fast-forward: every tracked file already in the main system was
retained, 31 tracked files were modified/added, and **no tracked file was
deleted**.

Locally generated material that the main worktree already had remains untouched
because it is gitignored, not tracked:

- `server/.env` (real local secrets — never overwritten),
- `server/node_modules/`,
- Flutter/Dart build caches: `client/build/`, `client/.dart_tool/`,
  `client/.flutter-plugins-dependencies`,
- platform-generated files (`local.properties`, `.gradle/`, generated plugin
  registrants, iOS/macOS ephemeral configs),
- `.github/modernize/` local tooling.

Before the merge, the main worktree had three **staged** files that were a
partial, degraded copy of the same mobile work (`.env.example` without the new
mobile knobs, an older `package-lock.json`, and a 005 migration differing only
by a trailing newline). They were preserved as a git stash named
`backup: pre-merge staged partial mobile feature copy (2026-11-27)` before the
fast-forward, so nothing was discarded. The complete, tested versions now come
from the milestone commits instead. The stash can be inspected with
`git stash list` and removed later with `git stash drop` once you are satisfied
with the merged result.

---

## 5. Verification performed after the merge

Run from `PowerPuffBoys-IS/server/`:

| Command | Result |
|---|---|
| `npm test` | 38/38 passing — includes token-expiry, client-config, stored-routine, integrity and mobile-config tests |
| `npm run smoke` | 64/64 checks passing against an isolated DB/port — full register/auth/CRUD/dashboard flow |

The Windows firewall rule, `CORS_ORIGIN` entry and phone run command are printed
by `npm run mobile:config`; see [`run-and-stop.md`](run-and-stop.md) §3 for the
step-by-step phone setup.

---

## 6. Known limitations and follow-ups

- Local notifications/reminders are still not implemented
  (`flutter_local_notifications` is not in `client/pubspec.yaml`).
- iOS builds need macOS/Xcode and were not verified on this Windows machine.
- Cleartext LAN HTTP is development-only; use HTTPS before any deployment.
- `mark_attendance` remains a direct-database routine so the API can keep
  returning `409` for duplicate attendance.
- This worktree is fast-forwarded to the same file tree as the upstream PR that
  already merged this feature into `origin/main`; the integration here records
  it on the local `fix/v2-ui-ux-followups` line of work.

---

## 7. Documentation map

| Document | Use it for |
|---|---|
| [`kickoff.md`](kickoff.md) | Project brief and first-time setup |
| [`run-and-stop.md`](run-and-stop.md) | Running, stopping and phone/LAN access |
| [`database.md`](database.md) | Schema, migrations, integrity, backup and rollback |
| [`mobile-ready-backend.md`](mobile-ready-backend.md) | Original feature record for the milestone |
| [`mobile-backend-migration.md`](mobile-backend-migration.md) | This integration record (what changed in main and why) |
| [`plan.md`](plan.md) | Technical plan, ERD and API reference |
| [`team-notes.md`](team-notes.md) | Team scratchpad and conflict drill |
