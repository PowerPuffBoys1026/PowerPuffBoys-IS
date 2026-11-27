# ClassMate — Database Guide

PostgreSQL is the single source of truth for all platforms (mobile, web and
desktop). The API never stores attendance percentages; it derives them from
attendance records so edits cannot leave a stale number behind.

---

## 1. Schema at a glance

| Migration | Adds |
|---|---|
| `001_initial_schema.sql` | Core tables: users, subjects, schedule_slots, attendance_records, school_works, notes + unique attendance indexes |
| `002_native_types.sql` | Native `date` / `time` / `timestamptz` columns and parser-friendly types |
| `003_constraints_and_indexes.sql` | Check constraints, per-user subject code uniqueness, composite indexes |
| `004_v2_features.sql` | Profile/schedule extensions, study sessions, grades, recycle bin, attachments |
| `005_stored_procedures.sql` | Shared routines for attendance summary, dashboard, marking attendance and work status |
| `006_mobile_query_indexes.sql` | Date and day-of-week indexes for mobile filters |

Detailed ERD: [`plan.md`](plan.md) §4. Tables are always scoped to
`user_id`; the API filters by the JWT user so one account cannot read another's
rows.

---

## 2. Applying migrations

```powershell
cd server
npm run db:create   # once, creates the database in .env
npm run db:init     # applies every pending migration
npm run dev         # also applies pending migrations on startup
```

`src/migrate.js` takes a session-level advisory lock, runs each SQL file in its
own transaction, and records successful files in `schema_migrations`. A failed
migration rolls back and can be retried after fixing the SQL. Never edit an
already-applied migration in place — add a new numbered file instead.

### Adding a migration

1. Create `server/migrations/007_your_change.sql`.
2. Make it idempotent where possible (`CREATE ... IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`).
3. Keep the naming and ownership conventions used in migration 005.
4. Run `npm test`; the throwaway-database tests apply all migrations from scratch.
5. Commit the migration in the same PR as the code that uses it.

---

## 3. Integrity rules to preserve

- `attendance_records` allows **one row per subject/date/slot** (two partial
  unique indexes cover rows with and without a slot).
- `subjects.code` is unique **per user**, not globally.
- `schedule_slots.start_time < end_time`; work type/priority/status and
  attendance status are constrained by `CHECK`s.
- Deleting a subject cascades its slots and attendance; optional links from
  school works and notes are set to `NULL` so the user keeps those rows.
- Attendance rate = `present / (present + absent + late)`; `cancelled` is
  ignored. The API calls `get_attendance_summary`, so this rule has one home.
- The API intentionally returns `409` for a duplicate attendance POST. The
  `mark_attendance` procedure is an upsert for direct database callers and is
  deliberately not used by that endpoint.

Verified by `npm test` (`test/stored-procedures.test.js` and
`test/data-integrity.test.js`) plus the end-to-end `npm run smoke`.

---

## 4. Backup and restore

Take a backup before any manual schema change, migration repair, or seed reset.
`psql`/`pg_dump` may not be on `PATH` on Windows; use the PostgreSQL install
directory (adjust the version if yours differs):

```powershell
$pg = "C:\Program Files\PostgreSQL\18\bin"

# Backup the application database
& "$pg\pg_dump.exe" -h localhost -U postgres -d classmate -F c -f classmate.backup

# Restore into an empty database (destructive — check the target name twice)
& "$pg\createdb.exe" -h localhost -U postgres classmate_restore
& "$pg\pg_restore.exe" -h localhost -U postgres -d classmate_restore classmate.backup
```

PgAdmin can do the same via **Backup…** / **Restore…** on the database node.

---

## 5. Rollback policy

Migrations are **forward-only**; there are no generated down files. Choose one:

1. **Restore a backup** (preferred when data must be preserved).
2. **Reverse the change manually** on a copy first, then apply to the real DB.
   Examples:

   ```sql
   -- Undo 006 only
   DROP INDEX IF EXISTS idx_attendance_date;
   DROP INDEX IF EXISTS idx_slots_day_of_week;

   -- Undo 005 routines only
   DROP PROCEDURE IF EXISTS set_work_status(integer, integer, text, integer);
   DROP PROCEDURE IF EXISTS mark_attendance(integer, integer, integer, date, text, text, integer, boolean);
   DROP FUNCTION IF EXISTS get_attendance_summary(integer, numeric);
   DROP FUNCTION IF EXISTS get_dashboard_classes(integer, smallint);
   DROP FUNCTION IF EXISTS get_due_soon_works(integer, date, integer);

   -- Only after the routines are gone (data loss!)
   -- DROP TABLE IF EXISTS attachments, subject_grades, study_sessions, recycle_bin;
   ```

3. Remove the corresponding row from `schema_migrations` if you need the
   runner to re-apply a fixed file.

Never run an untested rollback against the application database.

---

## 6. Mobile-specific notes

- `idx_attendance_date` supports date-range filters from the attendance screen.
- `idx_slots_day_of_week` supports the day/week timetable views.
- `get_due_soon_works` treats "due soon" as `due_at::date <= today + 7 days`,
  using `APP_TIMEZONE` (default `Asia/Manila`) so a phone in another timezone
  sees the same result as the web app.
- Fetch `/api/client-config` at app startup for the attendance threshold and
  allowed enum values instead of hard-coding them in the client.
