# Backlog

Use this document to track and fill in project backlog items for ClassMate.

_Last generated: 2026-11-12 (based on current repo/branch state: `feat/db-stored-procedures-security` @ `2874a11`, `feat/v2-ui-ux-integration` @ `498f046`, `main` @ `5e7d29e`). Review and adjust priorities/owners as needed._

## How to use
- Add new items under **To Do** with a clear title, description, priority, and owner (if known).
- Move items across sections as work progresses.
- Link related issues/PRs/docs where applicable.

## To Do
| ID | Title | Description | Priority | Owner | Notes/Links |
|---|---|---|---|---|---|
| BL-001 | Apply migration 005 and DB smoke test | Run `cd server && npm run migrate` (or start server) against local PostgreSQL `classmate` to apply `server/migrations/005_stored_procedures.sql`, then smoke-test auth, subjects, schedule, attendance (+ summary), works, notes, dashboard, study, grades, attachments, and recycle-bin (trash/restore/permanent delete). Confirm `GET /api/health` reports `database: ok`. | High | _Unassigned_ | `docs/STORED_PROCEDURES.md`; branch `feat/db-stored-procedures-security` |
| BL-002 | Review and merge PRs in order | Get review/merge for `feat/v2-ui-ux-integration` then `feat/db-stored-procedures-security` into `main` (do not push directly to protected `main`). Resolve any conflicts and ensure migration order 001–005 applies cleanly. | High | _Unassigned_ | PRs: https://github.com/PowerPuffBoys1026/PowerPuffBoys-IS/pull/new/feat/v2-ui-ux-integration, https://github.com/PowerPuffBoys1026/PowerPuffBoys-IS/pull/new/feat/db-stored-procedures-security |
| BL-003 | Run and update existing automated tests | Execute `cd server && npm test` and `npm run smoke` against a migrated test/dev DB. Update `server/test/api.test.js`, `server/test/unit.test.js`, and `server/scripts/smoke.js` as needed to reflect stored-proc/routine behavior and v2 contracts (e.g. soft-delete/recycle-bin responses like `{ data: { success, recycleBinId } }` where applicable, extended fields). | High | _Unassigned_ | Existing tests: `server/test/api.test.js`, `server/test/unit.test.js`, `client/test/format_test.dart` |
| BL-004 | Verify seed script with routines | Run `cd server && npm run seed` on a dev DB and confirm demo user/subjects/schedule/works are created correctly via routine-backed calls; fix any parameter/shape issues. | High | _Unassigned_ | `server/src/seed.js` refactored to use `fn_*` routines |
| BL-005 | Add test coverage for v2 and recycle-bin flows | Add integration tests for study sessions/stats, grades (+ summary), attachments (upload/list/download/delete), recycle-bin (list/trash/restore/permanent delete/expiry behavior), and v2-extended fields (subjects/schedule/notes/profile). | Medium | _Unassigned_ | Builds on BL-003 |
| BL-006 | Security review of stored routines and DB privileges | Review routines in `005_stored_procedures.sql` for ownership enforcement, edge cases, and least-privilege execution; consider a dedicated DB role with EXECUTE-only access (no direct table writes) and validate error/exception messages don’t leak sensitive info. | Medium | _Unassigned_ | `server/migrations/005_stored_procedures.sql`, `docs/STORED_PROCEDURES.md` |
| BL-007 | Flutter client API compatibility check | Verify Flutter app (`client/`) works end-to-end against the refactored/v2 API (auth, CRUD, dashboard, and any v2-backed features surfaced in client), including delete/recycle responses and error messages. | Medium | _Unassigned_ | `client/lib/config.dart`, `client/lib/state/*` |
| BL-008 | CORS/LAN configuration hardening | Document and validate `CORS_ORIGIN`, bind/port, and firewall settings for non-localhost/LAN usage (e.g. `http://192.168.x.x:3000`); ensure defaults remain safe for local dev. | Medium | _Unassigned_ | `server/src/config.js`, `server/.env` (local only) |
| BL-009 | API documentation (OpenAPI/endpoint reference) | Produce/update an API reference covering request/response contracts (including v2 endpoints and routine-backed behaviors) to aid frontend, QA, and instructor review. | Medium | _Unassigned_ | Align with `Version 2 UI UX/public/app.js` (`API_BASE='/api'`) |
| BL-010 | CI pipeline for migrate/test/smoke | Add CI workflow to spin up PostgreSQL, run migrations, execute `npm test` and smoke checks on PRs/merges to prevent regressions. | Medium | _Unassigned_ | `server/package.json` scripts: `migrate`, `test`, `smoke` |
| BL-011 | Attachment and upload hardening review | Review file size/type limits, storage paths, filename handling, and cleanup on delete/purge/restore to prevent abuse or orphaned files. | Low | _Unassigned_ | `server/src/services/attachments.js`, `server/src/routes/attachments.js` |
| BL-012 | Performance and indexing review for routine queries | Inspect query plans for list/stats/summary routines (notes search, dashboard, grades/study stats, recycle-bin) and add/adjust indexes as needed for expected data sizes. | Low | _Unassigned_ | `server/migrations/004_v2_features.sql`, `005_stored_procedures.sql` |

## In Progress
| ID | Title | Description | Priority | Owner | Notes/Links |
|---|---|---|---|---|---|

## Blocked
| ID | Title | Description | Blocker | Owner | Notes/Links |
|---|---|---|---|---|---|

## Done
| ID | Title | Description | Completed By | Date | Notes/Links |
|---|---|---|---|---|---|
| BL-D01 | v2 UI/UX integration (server/web/client theme) | Integrated v2 web frontend, v2 schema/features (study/grades/attachments/recycle-bin, extensions), and Flutter v2 theme on PostgreSQL. | Team | 2026-11 (prior) | `feat/v2-ui-ux-integration` @ `498f046` |
| BL-D02 | Stored-procedure refactor and security hardening | Added migration 005 routines and refactored app data access to parameterized routine calls; added `docs/STORED_PROCEDURES.md`. | Team | 2026-11 (prior) | `feat/db-stored-procedures-security` @ `2874a11` |

## Ideas / Icebox
- Add rate-limiting/abuse protections review for auth and write-heavy endpoints.
- Add audit logging for sensitive actions (auth events, deletes/restores).
- Provide DB backup/restore and migration rollback guidance for deployments.
- Improve user-facing error messages and observability (structured logs/metrics/health details).
- Evaluate pagination/consistency across all list endpoints and large-dataset UX.
- Consider refresh-token/session rotation strategy and password policy enhancements.
