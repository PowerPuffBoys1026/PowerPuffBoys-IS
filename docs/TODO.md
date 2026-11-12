# ClassMate App — To Do

_Actionable to-do list for the ClassMate system (server, web, client). Label: **backlogs**._

_Last updated: 2026-11-12 (branches: `feat/db-stored-procedures-security` @ `2874a11`, `feat/v2-ui-ux-integration` @ `498f046`)._

## High priority

- [ ] **Apply migration 005 & smoke test (DB)**
  - Run `cd server && npm run migrate` (or start server) on PostgreSQL `classmate` to apply `server/migrations/005_stored_procedures.sql`.
  - Smoke-test: auth, subjects, schedule, attendance (+ summary), works, notes, dashboard, study, grades, attachments, recycle-bin (trash/restore/permanent delete).
  - Confirm `GET /api/health` returns `"status":"ok"` and `"database":"ok"`.
  - Ref: `docs/STORED_PROCEDURES.md`

- [ ] **Review and merge PRs in order**
  - Merge `feat/v2-ui-ux-integration` then `feat/db-stored-procedures-security` into `main` via PRs (do not push directly to protected `main`).
  - Resolve conflicts and verify migrations 001–005 apply cleanly in order.
  - PRs: https://github.com/PowerPuffBoys1026/PowerPuffBoys-IS/pull/new/feat/v2-ui-ux-integration, https://github.com/PowerPuffBoys1026/PowerPuffBoys-IS/pull/new/feat/db-stored-procedures-security

- [ ] **Run and update existing automated tests**
  - Run `cd server && npm test` and `npm run smoke` against a migrated DB.
  - Update `server/test/api.test.js`, `server/test/unit.test.js`, and `server/scripts/smoke.js` for stored-proc/v2 behavior (e.g. soft-delete/recycle-bin responses like `{ data: { success, recycleBinId } }` where applicable, extended fields).
  - Client: `client/test/format_test.dart` (verify as needed).

- [ ] **Verify seed script with routines**
  - Run `cd server && npm run seed` on a dev DB and confirm demo data is created correctly via routine-backed calls.

## Medium priority

- [ ] **Add v2 & recycle-bin test coverage**
  - Integration tests for study sessions/stats, grades (+ summary), attachments (upload/list/download/delete), recycle-bin (list/trash/restore/permanent delete/expiry), and v2-extended fields.

- [ ] **Security review of routines & DB privileges**
  - Review `server/migrations/005_stored_procedures.sql` for ownership enforcement/edge cases.
  - Consider least-privilege DB role (EXECUTE-only, no direct table writes) and ensure errors don’t leak sensitive info.

- [ ] **Flutter client compatibility check**
  - Verify `client/` works end-to-end against refactored/v2 API (auth, CRUD, dashboard, v2 features), including delete/recycle responses and error handling.

- [ ] **CORS/LAN configuration**
  - Document/validate `CORS_ORIGIN`, bind/port, and firewall for non-localhost/LAN use; keep safe defaults for local dev. (`server/src/config.js`)

- [ ] **API documentation**
  - Produce/update endpoint reference (OpenAPI or markdown) covering request/response contracts, v2 endpoints, and routine-backed behaviors.

- [ ] **CI pipeline**
  - Add CI to provision PostgreSQL, run migrations, and execute `npm test` + smoke checks on PRs/merges.

## Low priority / enhancements

- [ ] **Attachment/upload hardening review** — size/type limits, storage paths, filename handling, cleanup on delete/purge/restore (`server/src/services/attachments.js`).
- [ ] **Performance & indexing review** — inspect query plans for list/stats/summary routines (notes search, dashboard, grades/study stats, recycle-bin) and adjust indexes (`004_v2_features.sql`, `005_stored_procedures.sql`).

## Bug-fix / verification notes
- **Potential compat breaks:** existing API tests/smoke may fail due to soft-delete/recycle-bin response changes and v2 contract updates — address in “Run and update existing automated tests”.
- **Dependency:** server requires migration 005 applied before it functions against the DB.

## Completed (reference)
- [x] v2 UI/UX integration (web frontend, v2 features/schema, Flutter theme) — `feat/v2-ui-ux-integration` @ `498f046`
- [x] Stored-procedure refactor & SQL-injection hardening (migration 005, routine-backed data access, docs) — `feat/db-stored-procedures-security` @ `2874a11`, `docs/STORED_PROCEDURES.md`
