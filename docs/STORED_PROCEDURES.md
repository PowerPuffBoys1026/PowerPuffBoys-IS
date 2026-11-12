# Stored Procedures & Secure Data Access (ClassMate Server)

## Purpose
This change implements the instructor-required **stored procedure standard** and hardens database access to reduce SQL-injection risk:

- All application **data access logic** is encapsulated in PostgreSQL **stored routines** (functions / PL/pgSQL) defined in a migration.
- The Node.js server calls these routines using **parameterized queries only** (e.g. `db.query('SELECT * FROM fn_*(,,...)', [values])`).
- Inline/dynamic SQL composition in application request paths (models/services/routes) is removed in favor of routine calls. Values are never concatenated into SQL; dynamic filtering (e.g. notes search/tag) is handled inside routines with parameterized predicates/escaping.
- Transactional recycle-bin operations (trash/restore/purge) are executed atomically inside database routines.

## Migration
- **`server/migrations/005_stored_procedures.sql`**
  - Applied automatically by `server/src/migrate.js` (recorded in `schema_migrations`) on server startup / `npm run migrate`.
  - Creates/replaces routines idempotently (`CREATE OR REPLACE`).

## How the application calls routines
- DB access goes through `server/src/db.js` (pg Pool) with parameter placeholders (\..\).
- Routine exceptions for domain errors are mapped in `server/src/services/recycle_bin.js` (e.g. `NOT_FOUND:` / `BAD_REQUEST:` prefixes, FK `23503` -> conflict).

## Routine catalog (by domain)

### Users (`fn_user_*`)
- `fn_user_find_by_email(p_email)` -> SETOF users
- `fn_user_find_by_id(p_id)` -> SETOF users
- `fn_user_create(p_email,p_password_hash,p_full_name,p_student_no,p_course,p_year_level)` -> SETOF users
- `fn_user_update_profile(p_id,p_full_name,p_student_no,p_course,p_year_level)` -> SETOF users
- `fn_user_update_password(p_id,p_password_hash)` -> VOID
- `fn_user_exists_by_email(p_email)` -> BOOLEAN

### Subjects (`fn_subject_*`)
- `fn_subjects_list`, `fn_subject_get`, `fn_subject_create`, `fn_subject_update`, `fn_subject_delete` (count), `fn_subject_owned` (BOOLEAN)

### Schedule (`fn_schedule_*`, `fn_slot_exists_for_subject_user`)
List/get/create/update/delete schedule slots with joined subject fields; ownership enforced in routines.

### Attendance (`fn_attendance_*`)
Duplicate detection, create/get/list (filters/paging), update (explicit-null set-flags), delete, and `fn_attendance_summary` aggregates. Rate/warning computation remains in `server/src/services/attendance.js`.

### Works (`fn_work_*`)
List/create/get/update/update-status/delete with joined subject fields and ownership checks.

### Notes (`fn_note_*`)
List with safe filtering (search/tag/subject/pinned/paging; escaped inside routine), create/get/update/toggle-pin/delete with joined subject fields.

### Dashboard (`fn_dashboard_*`)
`fn_dashboard_classes(user,day)` and `fn_dashboard_due_soon(user,today)`.

### Study (`fn_study_*`)
Session list/create, ownership check, and stats helpers (today/week/all, by-subject, active days). Streak computed in `server/src/routes/study.js`.

### Grades (`fn_grade_*`)
List/get/create/update/ownership and summary data queries. GPA/standing calculated in `server/src/routes/grades.js`.

### Attachments (`fn_attachment_*`)
Add/list/list-all/get-owned/delete/delete-for-resource plus route helpers `fn_attachment_resource_owned`, `fn_attachment_count`. Filesystem handling remains in `server/src/services/attachments.js`.

### Recycle Bin (`fn_recycle_*`)
- `fn_recycle_purge_expired(p_user_id)`: removes expired items and returns them for app-side file cleanup.
- `fn_recycle_list/get/delete`: bin entry operations.
- `fn_recycle_trash(p_user_id,p_type,p_id)`: atomically snapshots and soft-deletes supported types (`subject` with related records, `note`, `task`, `session`, `grade`, `schedule`, `attendance`); returns recycle-bin id.
- `fn_recycle_restore(p_user_id,p_id)`: atomically restores snapshots (per-type), fixes invalid attendance slot refs, resets sequences, removes bin entry.
- `server/src/services/recycle_bin.js` orchestrates file cleanup and maps routine errors to API errors.

## Refactored application files
- Models: `server/src/models/{user,subject,schedule,attendance,work,note,dashboard}.model.js`
- Services: `server/src/services/{attendance,attachments,recycle_bin}.js`
- Routes (data access): `server/src/routes/{study,grades,attachments}.js`
- Dev seed: `server/src/seed.js`

`server/src/migrate.js` remains migration infrastructure (executes migration files).

## Verification notes
- Modified server modules pass JavaScript syntax checks.
- Apply migration 005 against the target PostgreSQL database (`npm run migrate` or server start) before running; routines must exist for the refactored server.
- Recommended smoke tests after applying: auth, subjects/schedule/attendance/works/notes, dashboard, study, grades, attachments, recycle-bin (trash/restore), and seed on a dev DB.