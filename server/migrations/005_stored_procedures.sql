-- Stored routines for the ClassMate database.
--
-- Conventions used here (keep new database routines consistent with these):
--   * Naming: verb_noun (get_attendance_summary, mark_attendance, set_work_status).
--   * `CREATE OR REPLACE` so the file is safe to apply more than once by hand.
--   * Explicit parameter prefixes (`p_`) to avoid clashing with column names.
--   * `SECURITY INVOKER` (the caller's privileges apply) plus a fixed
--     `search_path`, so an untrusted session cannot redirect name resolution.
--   * Validation failures raise a SQLSTATE: 22023 for bad input, P0002 for a
--     resource that is missing or not owned by the caller.
--   * Every routine is documented with `COMMENT ON` and every ownership check
--     is performed inside the routine, never left to the caller.
--
-- Read routines are functions (they return rows); write routines are
-- procedures (they return results through INOUT parameters and must be called
-- with `CALL`). The Node API does not call these yet.

-- ---------------------------------------------------------------------------
-- get_attendance_summary(user, threshold)
--   Per-subject attendance totals and rates for one user.
--   Attendance rate = present / (present + absent + late); cancelled sessions
--   are counted but ignored in the rate, matching src/services/attendance.js.
--   A subject is a warning when the absence rate reaches `p_threshold` or the
--   student has used all 28-session allowance (minimum 3 absences).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_attendance_summary(
  p_user_id   integer,
  p_threshold numeric DEFAULT 20
)
RETURNS TABLE (
  subject_id        integer,
  code              text,
  title             text,
  color             text,
  present           integer,
  absent            integer,
  late              integer,
  cancelled         integer,
  counted           integer,
  attendance_rate   numeric,
  absence_rate      numeric,
  safe_misses_left  integer,
  health_status     text,
  warning           boolean
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_max_allowed integer;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required' USING ERRCODE = '22023';
  END IF;
  IF p_threshold IS NULL OR p_threshold < 0 OR p_threshold > 100 THEN
    RAISE EXCEPTION 'p_threshold must be between 0 and 100' USING ERRCODE = '22023';
  END IF;

  -- Same allowance used by the API: at least 3, otherwise 28 * threshold%.
  v_max_allowed := GREATEST(3, FLOOR(p_threshold / 100.0 * 28));

  RETURN QUERY
  SELECT
    s.id,
    s.code,
    s.title,
    s.color,
    COALESCE(SUM(CASE WHEN a.status = 'present'   THEN 1 ELSE 0 END), 0)::integer AS present,
    COALESCE(SUM(CASE WHEN a.status = 'absent'    THEN 1 ELSE 0 END), 0)::integer AS absent,
    COALESCE(SUM(CASE WHEN a.status = 'late'      THEN 1 ELSE 0 END), 0)::integer AS late,
    COALESCE(SUM(CASE WHEN a.status = 'cancelled' THEN 1 ELSE 0 END), 0)::integer AS cancelled,
    COALESCE(SUM(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 ELSE 0 END), 0)::integer AS counted,
    CASE
      WHEN SUM(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 ELSE 0 END) = 0 THEN NULL
      ELSE ROUND(
        SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END)::numeric * 100.0
          / SUM(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 ELSE 0 END),
        1
      )
    END AS attendance_rate,
    CASE
      WHEN SUM(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 ELSE 0 END) = 0 THEN NULL
      ELSE ROUND(
        SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END)::numeric * 100.0
          / SUM(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 ELSE 0 END),
        1
      )
    END AS absence_rate,
    GREATEST(
      0,
      v_max_allowed - COALESCE(SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END), 0)::integer
    ) AS safe_misses_left,
    CASE
      WHEN COALESCE(SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END), 0) > v_max_allowed THEN 'critical'
      WHEN COALESCE(SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END), 0) >= v_max_allowed
        OR (
          SUM(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 ELSE 0 END) > 0
          AND ROUND(
            SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END)::numeric * 100.0
              / SUM(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 ELSE 0 END),
            1
          ) >= p_threshold
        ) THEN 'warning'
      ELSE 'safe'
    END AS health_status,
    (
      COALESCE(SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END), 0) >= v_max_allowed
      OR (
        SUM(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 ELSE 0 END) > 0
        AND ROUND(
          SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END)::numeric * 100.0
            / SUM(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 ELSE 0 END),
          1
        ) >= p_threshold
      )
    ) AS warning
  FROM subjects s
  LEFT JOIN attendance_records a ON a.subject_id = s.id
  WHERE s.user_id = p_user_id
  GROUP BY s.id, s.code, s.title, s.color
  ORDER BY s.code;
END;
$$;

COMMENT ON FUNCTION get_attendance_summary(integer, numeric) IS
  'Per-subject attendance totals, rate and warning state for one user.';

-- ---------------------------------------------------------------------------
-- get_dashboard_classes(user, day_of_week)
--   The schedule slots for one user on a given day (0 = Sunday ... 6 = Saturday),
--   ordered by start time. Mirrors src/models/dashboard.model.js.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_dashboard_classes(
  p_user_id     integer,
  p_day_of_week smallint
)
RETURNS TABLE (
  slot_id     integer,
  start_time  time,
  end_time    time,
  room        text,
  modality    text,
  subject_id  integer,
  code        text,
  title       text,
  color       text
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required' USING ERRCODE = '22023';
  END IF;
  IF p_day_of_week IS NULL OR p_day_of_week < 0 OR p_day_of_week > 6 THEN
    RAISE EXCEPTION 'p_day_of_week must be between 0 and 6' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    sc.id,
    sc.start_time,
    sc.end_time,
    sc.room,
    sc.modality,
    s.id,
    s.code,
    s.title,
    s.color
  FROM schedule_slots sc
  JOIN subjects s ON s.id = sc.subject_id
  WHERE s.user_id = p_user_id
    AND sc.day_of_week = p_day_of_week
  ORDER BY sc.start_time;
END;
$$;

COMMENT ON FUNCTION get_dashboard_classes(integer, smallint) IS
  'Schedule slots for one user on a single day of the week, ordered by start time.';

-- ---------------------------------------------------------------------------
-- get_due_soon_works(user, today, days)
--   Unfinished school works due within `p_days` days of `p_today` (overdue
--   included), ordered by due date. Mirrors the dashboard "due soon" query.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_due_soon_works(
  p_user_id integer,
  p_today   date,
  p_days    integer DEFAULT 7
)
RETURNS TABLE (
  work_id        integer,
  title          text,
  work_type      text,
  due_at         timestamptz,
  priority       text,
  status         text,
  subject_code   text,
  color          text
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_user_id IS NULL OR p_today IS NULL THEN
    RAISE EXCEPTION 'p_user_id and p_today are required' USING ERRCODE = '22023';
  END IF;
  IF p_days IS NULL OR p_days < 0 THEN
    RAISE EXCEPTION 'p_days must be zero or greater' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    w.id,
    w.title,
    w.type,
    w.due_at,
    w.priority,
    w.status,
    s.code,
    s.color
  FROM school_works w
  LEFT JOIN subjects s ON s.id = w.subject_id
  WHERE w.user_id = p_user_id
    AND w.status <> 'done'
    AND w.due_at IS NOT NULL
    AND w.due_at::date <= p_today + p_days
  ORDER BY w.due_at;
END;
$$;

COMMENT ON FUNCTION get_due_soon_works(integer, date, integer) IS
  'Unfinished school works due within N days of a date (overdue included).';

-- ---------------------------------------------------------------------------
-- mark_attendance(user, subject, slot, date, status, note)
--   Insert or update the attendance record for a subject/date/slot. Returns
--   the record id and whether it was newly created. Ownership and the
--   subject/slot relationship are validated here so callers cannot write
--   across users.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE mark_attendance(
  p_user_id        integer,
  p_subject_id     integer,
  p_slot_id        integer,
  p_date           date,
  p_status         text,
  p_note           text,
  INOUT p_attendance_id integer DEFAULT NULL,
  INOUT p_was_created   boolean DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_user_id IS NULL OR p_subject_id IS NULL OR p_date IS NULL THEN
    RAISE EXCEPTION 'p_user_id, p_subject_id and p_date are required' USING ERRCODE = '22023';
  END IF;
  IF p_status IS NULL OR p_status NOT IN ('present', 'absent', 'late', 'cancelled') THEN
    RAISE EXCEPTION 'p_status must be present, absent, late or cancelled' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM subjects s
    WHERE s.id = p_subject_id AND s.user_id = p_user_id
  ) THEN
    RAISE EXCEPTION 'Subject % was not found for this user', p_subject_id USING ERRCODE = 'P0002';
  END IF;

  IF p_slot_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM schedule_slots sc
    WHERE sc.id = p_slot_id AND sc.subject_id = p_subject_id
  ) THEN
    RAISE EXCEPTION 'Slot % does not belong to subject %', p_slot_id, p_subject_id
      USING ERRCODE = 'P0002';
  END IF;

  p_attendance_id := NULL;
  p_was_created := FALSE;

  -- The partial unique indexes on attendance_records enforce one record per
  -- subject/date/slot. DO NOTHING turns a concurrent duplicate into an update.
  INSERT INTO attendance_records (subject_id, slot_id, date, status, note)
  VALUES (p_subject_id, p_slot_id, p_date, p_status, p_note)
  ON CONFLICT DO NOTHING
  RETURNING id INTO p_attendance_id;

  IF p_attendance_id IS NOT NULL THEN
    p_was_created := TRUE;
    RETURN;
  END IF;

  UPDATE attendance_records
     SET status = p_status,
         note = p_note
   WHERE subject_id = p_subject_id
     AND date = p_date
     AND slot_id IS NOT DISTINCT FROM p_slot_id
  RETURNING id INTO p_attendance_id;

  IF p_attendance_id IS NULL THEN
    RAISE EXCEPTION 'Attendance record could not be saved' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

COMMENT ON PROCEDURE mark_attendance(integer, integer, integer, date, text, text, integer, boolean) IS
  'Insert or update one attendance record after validating ownership.';

-- ---------------------------------------------------------------------------
-- set_work_status(user, work, status)
--   Change a school work's status after checking it belongs to the user.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE set_work_status(
  p_user_id   integer,
  p_work_id   integer,
  p_status    text,
  INOUT p_updated_id integer DEFAULT NULL
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_user_id IS NULL OR p_work_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id and p_work_id are required' USING ERRCODE = '22023';
  END IF;
  IF p_status IS NULL OR p_status NOT IN ('todo', 'doing', 'done') THEN
    RAISE EXCEPTION 'p_status must be todo, doing or done' USING ERRCODE = '22023';
  END IF;

  UPDATE school_works w
     SET status = p_status,
         updated_at = NOW()
   WHERE w.id = p_work_id
     AND w.user_id = p_user_id
  RETURNING w.id INTO p_updated_id;

  IF p_updated_id IS NULL THEN
    RAISE EXCEPTION 'Work % was not found for this user', p_work_id USING ERRCODE = 'P0002';
  END IF;
END;
$$;

COMMENT ON PROCEDURE set_work_status(integer, integer, text, integer) IS
  'Update a school work status after validating ownership.';
