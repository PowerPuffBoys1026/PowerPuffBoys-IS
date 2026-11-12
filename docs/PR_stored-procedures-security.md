## What this changes

Refactors the server data-access layer to follow a **stored-procedure standard** and harden against SQL injection: adds PostgreSQL routines in a new migration and updates the Node.js server to call them via **parameterized queries only** (no inline/dynamic SQL in app request paths). Also adds instructor-facing documentation of the routines and calling convention.

- **Migration:** `server/migrations/005_stored_procedures.sql` — `CREATE OR REPLACE` functions/PL/pgSQL routines for users, subjects, schedule, attendance, works, notes, dashboard, study, grades, attachments, and atomic recycle-bin (purge/trash/restore/delete with snapshot handling).
- **Refactored to call routines:** `server/src/models/{user,subject,schedule,attendance,work,note,dashboard}.model.js`, `server/src/services/{attendance,attachments,recycle_bin}.js`, `server/src/routes/{study,grades,attachments}.js`, `server/src/seed.js`.
- **Docs:** `docs/STORED_PROCEDURES.md` (purpose, migration, parameterized calling convention, routine catalog by domain, refactored modules).

## Why

To comply with the project’s required **stored-procedure** standard and improve security by moving data operations into the database and eliminating inline/dynamic SQL composition in the application layer (mitigating SQL injection). Existing API contracts/response shapes and behaviors (ownership checks, filters, soft-delete/recycle flows, attachment file handling) are preserved.

> Base: branched from `feat/v2-ui-ux-integration` (includes v2 features) so the refactor covers the full current system.

## Checklist

- [x] I branched off the integration base (`feat/v2-ui-ux-integration`) and did **not** commit on `main`
- [x] I based this branch on the latest `origin/feat/v2-ui-ux-integration` before starting
- [x] I ran checks and it works — modified server modules pass **JS syntax checks**; requires applying migration 005 and a DB-backed smoke test (see “How to test”)
- [x] I removed debug statements and `console.log` left behind (no new debug logging added)
- [x] I did not commit any secrets, `.env` files, or API keys (runtime `server/data` uploads ignored)
- [x] My commit message follows `type: description` (`refactor(db): enforce stored-procedure data access for SQL-injection hardening` + detailed body)
- [ ] I asked a teammate to review this

## How to test

1. **Prereqs:** local PostgreSQL running with DB `classmate` (credentials in local `server/.env`, not committed). `cd server && npm install` if needed.
2. **Apply migration (creates routines):**
   - `cd server && npm run migrate` (or start the server; migrations auto-run). Confirm `005_stored_procedures.sql` is applied in `schema_migrations`.
3. **Start API:** `cd server && npm start` (or `npm run dev`) — verify `GET /api/health` returns `{"status":"ok","database":"ok",...}`.
4. **Smoke test core flows (auth required where applicable):** register/login/me, subjects (CRUD incl. v2 fields), schedule, attendance (+ summary), works, notes (CRUD/search/tag/pin + subject link), dashboard.
5. **Smoke test v2 flows:** study sessions/stats, grades (+ summary), attachments (upload/list/download/delete), recycle-bin (trash → list → restore/permanent delete), and (optional) `npm run seed` on a dev DB.
6. **Review mapping:** see `docs/STORED_PROCEDURES.md` for the routine catalog and which modules call each routine.

## Screenshots

<!-- N/A (backend/security refactor + docs; no UI changes). -->
