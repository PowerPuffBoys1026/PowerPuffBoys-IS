-- 005_stored_procedures.sql
-- Encapsulate data access in PostgreSQL routines (security hardening / stored-procedure standard).
-- Application code calls these routines with parameterized arguments only.

-- =========================
-- USERS
-- =========================
CREATE OR REPLACE FUNCTION fn_user_find_by_email(p_email TEXT)
RETURNS SETOF users LANGUAGE sql STABLE AS $$
  SELECT * FROM users WHERE email = p_email LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_user_find_by_id(p_id INTEGER)
RETURNS SETOF users LANGUAGE sql STABLE AS $$
  SELECT * FROM users WHERE id = p_id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_user_create(
  p_email TEXT, p_password_hash TEXT, p_full_name TEXT,
  p_student_no TEXT, p_course TEXT, p_year_level TEXT
) RETURNS SETOF users LANGUAGE sql AS $$
  INSERT INTO users (email, password_hash, full_name, student_no, course, year_level)
  VALUES (p_email, p_password_hash, p_full_name, p_student_no, p_course, p_year_level)
  RETURNING *;
$$;

CREATE OR REPLACE FUNCTION fn_user_update_profile(
  p_id INTEGER, p_full_name TEXT, p_student_no TEXT, p_course TEXT, p_year_level TEXT
) RETURNS SETOF users LANGUAGE sql AS $$
  UPDATE users SET full_name = p_full_name, student_no = p_student_no, course = p_course, year_level = p_year_level
  WHERE id = p_id RETURNING *;
$$;

CREATE OR REPLACE FUNCTION fn_user_update_password(p_id INTEGER, p_password_hash TEXT)
RETURNS VOID LANGUAGE sql AS $$
  UPDATE users SET password_hash = p_password_hash WHERE id = p_id;
$$;

CREATE OR REPLACE FUNCTION fn_user_exists_by_email(p_email TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS(SELECT 1 FROM users WHERE email = p_email);
$$;

-- =========================
-- SUBJECTS
-- =========================
CREATE OR REPLACE FUNCTION fn_subjects_list(p_user_id INTEGER, p_limit INTEGER DEFAULT NULL, p_offset INTEGER DEFAULT NULL)
RETURNS SETOF subjects LANGUAGE sql STABLE AS $$
  SELECT * FROM subjects WHERE user_id = p_user_id ORDER BY code
  LIMIT p_limit OFFSET COALESCE(p_offset, 0);
$$;

CREATE OR REPLACE FUNCTION fn_subject_get(p_id INTEGER, p_user_id INTEGER)
RETURNS SETOF subjects LANGUAGE sql STABLE AS $$
  SELECT * FROM subjects WHERE id = p_id AND user_id = p_user_id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_subject_create(
  p_user_id INTEGER, p_code TEXT, p_title TEXT, p_instructor TEXT,
  p_instructor_email TEXT, p_office_hours TEXT, p_units INTEGER, p_color TEXT
) RETURNS SETOF subjects LANGUAGE sql AS $$
  INSERT INTO subjects (user_id, code, title, instructor, instructor_email, office_hours, units, color)
  VALUES (p_user_id, p_code, p_title, p_instructor, p_instructor_email, p_office_hours, COALESCE(p_units,0), COALESCE(p_color,'#4F46E5'))
  RETURNING *;
$$;

CREATE OR REPLACE FUNCTION fn_subject_update(
  p_id INTEGER, p_user_id INTEGER, p_code TEXT, p_title TEXT, p_instructor TEXT,
  p_instructor_email TEXT, p_office_hours TEXT, p_units INTEGER, p_color TEXT
) RETURNS SETOF subjects LANGUAGE sql AS $$
  UPDATE subjects SET code = p_code, title = p_title, instructor = p_instructor,
    instructor_email = p_instructor_email, office_hours = p_office_hours, units = p_units, color = p_color
  WHERE id = p_id AND user_id = p_user_id RETURNING *;
$$;

CREATE OR REPLACE FUNCTION fn_subject_delete(p_id INTEGER, p_user_id INTEGER)
RETURNS INTEGER LANGUAGE sql AS $$
  WITH d AS (DELETE FROM subjects WHERE id = p_id AND user_id = p_user_id RETURNING id)
  SELECT COUNT(*)::int FROM d;
$$;

CREATE OR REPLACE FUNCTION fn_subject_owned(p_subject_id INTEGER, p_user_id INTEGER)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS(SELECT 1 FROM subjects WHERE id = p_subject_id AND user_id = p_user_id);
$$;

-- =========================
-- SCHEDULE
-- =========================
CREATE OR REPLACE FUNCTION fn_schedule_list(p_user_id INTEGER, p_day INTEGER DEFAULT NULL, p_limit INTEGER DEFAULT NULL, p_offset INTEGER DEFAULT NULL)
RETURNS TABLE (
  id INT, subject_id INT, day_of_week INT, start_time TIME, end_time TIME, room TEXT, building TEXT, modality TEXT, week_pattern TEXT,
  subject_code TEXT, subject_title TEXT, color TEXT
) LANGUAGE sql STABLE AS $$
  SELECT sc.id, sc.subject_id, sc.day_of_week, sc.start_time, sc.end_time, sc.room, sc.building, sc.modality, sc.week_pattern,
         s.code AS subject_code, s.title AS subject_title, s.color
    FROM schedule_slots sc JOIN subjects s ON s.id = sc.subject_id
   WHERE s.user_id = p_user_id AND (p_day IS NULL OR sc.day_of_week = p_day)
   ORDER BY sc.day_of_week, sc.start_time
   LIMIT p_limit OFFSET COALESCE(p_offset,0);
$$;

CREATE OR REPLACE FUNCTION fn_schedule_get(p_id INTEGER, p_user_id INTEGER)
RETURNS TABLE (
  id INT, subject_id INT, day_of_week INT, start_time TIME, end_time TIME, room TEXT, building TEXT, modality TEXT, week_pattern TEXT,
  subject_code TEXT, subject_title TEXT, color TEXT
) LANGUAGE sql STABLE AS $$
  SELECT sc.id, sc.subject_id, sc.day_of_week, sc.start_time, sc.end_time, sc.room, sc.building, sc.modality, sc.week_pattern,
         s.code AS subject_code, s.title AS subject_title, s.color
    FROM schedule_slots sc JOIN subjects s ON s.id = sc.subject_id
   WHERE sc.id = p_id AND s.user_id = p_user_id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_schedule_create(
  p_subject_id INT, p_day_of_week INT, p_start_time TIME, p_end_time TIME,
  p_room TEXT, p_building TEXT, p_modality TEXT, p_week_pattern TEXT
) RETURNS TABLE (
  id INT, subject_id INT, day_of_week INT, start_time TIME, end_time TIME, room TEXT, building TEXT, modality TEXT, week_pattern TEXT,
  subject_code TEXT, subject_title TEXT, color TEXT
) LANGUAGE sql AS $$
  WITH inserted AS (
    INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time, room, building, modality, week_pattern)
    VALUES (p_subject_id, p_day_of_week, p_start_time, p_end_time, p_room, p_building, p_modality, COALESCE(p_week_pattern,'every'))
    RETURNING *
  )
  SELECT i.id, i.subject_id, i.day_of_week, i.start_time, i.end_time, i.room, i.building, i.modality, i.week_pattern,
         s.code, s.title, s.color
    FROM inserted i JOIN subjects s ON s.id = i.subject_id;
$$;

CREATE OR REPLACE FUNCTION fn_schedule_update(
  p_id INT, p_user_id INT, p_subject_id INT, p_day_of_week INT, p_start_time TIME, p_end_time TIME,
  p_room TEXT, p_building TEXT, p_modality TEXT, p_week_pattern TEXT
) RETURNS TABLE (
  id INT, subject_id INT, day_of_week INT, start_time TIME, end_time TIME, room TEXT, building TEXT, modality TEXT, week_pattern TEXT,
  subject_code TEXT, subject_title TEXT, color TEXT
) LANGUAGE sql AS $$
  WITH updated AS (
    UPDATE schedule_slots sc
       SET subject_id = p_subject_id, day_of_week = p_day_of_week, start_time = p_start_time, end_time = p_end_time,
           room = p_room, building = p_building, modality = p_modality, week_pattern = p_week_pattern
      FROM subjects s
     WHERE sc.id = p_id AND sc.subject_id = s.id AND s.user_id = p_user_id
     RETURNING sc.*
  )
  SELECT u.id, u.subject_id, u.day_of_week, u.start_time, u.end_time, u.room, u.building, u.modality, u.week_pattern,
         s.code, s.title, s.color
    FROM updated u JOIN subjects s ON s.id = u.subject_id;
$$;

CREATE OR REPLACE FUNCTION fn_schedule_delete(p_id INT, p_user_id INT)
RETURNS INTEGER LANGUAGE sql AS $$
  WITH d AS (
    DELETE FROM schedule_slots sc USING subjects s
     WHERE sc.id = p_id AND sc.subject_id = s.id AND s.user_id = p_user_id RETURNING sc.id
  ) SELECT COUNT(*)::int FROM d;
$$;

CREATE OR REPLACE FUNCTION fn_slot_exists_for_subject_user(p_slot_id INT, p_subject_id INT, p_user_id INT)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS(
    SELECT 1 FROM schedule_slots sc JOIN subjects s ON s.id = sc.subject_id
     WHERE sc.id = p_slot_id AND sc.subject_id = p_subject_id AND s.user_id = p_user_id
  );
$$;

-- =========================
-- ATTENDANCE
-- =========================
CREATE OR REPLACE FUNCTION fn_attendance_find_duplicate(p_subject_id INT, p_date DATE, p_slot_id INT, p_exclude_id INT DEFAULT NULL)
RETURNS SETOF attendance_records LANGUAGE sql STABLE AS $$
  SELECT * FROM attendance_records a
   WHERE a.subject_id = p_subject_id AND a.date = p_date
     AND ((p_slot_id IS NULL AND a.slot_id IS NULL) OR (p_slot_id IS NOT NULL AND a.slot_id = p_slot_id))
     AND (p_exclude_id IS NULL OR a.id <> p_exclude_id)
   LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_attendance_create(p_subject_id INT, p_slot_id INT, p_date DATE, p_status TEXT, p_note TEXT)
RETURNS SETOF attendance_records LANGUAGE sql AS $$
  INSERT INTO attendance_records (subject_id, slot_id, date, status, note)
  VALUES (p_subject_id, p_slot_id, p_date, p_status, p_note) RETURNING *;
$$;

CREATE OR REPLACE FUNCTION fn_attendance_get(p_id INT, p_user_id INT)
RETURNS SETOF attendance_records LANGUAGE sql STABLE AS $$
  SELECT a.* FROM attendance_records a JOIN subjects s ON s.id = a.subject_id
   WHERE a.id = p_id AND s.user_id = p_user_id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_attendance_list(
  p_user_id INT, p_subject_id INT DEFAULT NULL, p_from DATE DEFAULT NULL, p_to DATE DEFAULT NULL,
  p_limit INT DEFAULT NULL, p_offset INT DEFAULT NULL
) RETURNS SETOF attendance_records LANGUAGE sql STABLE AS $$
  SELECT a.* FROM attendance_records a JOIN subjects s ON s.id = a.subject_id
   WHERE s.user_id = p_user_id
     AND (p_subject_id IS NULL OR a.subject_id = p_subject_id)
     AND (p_from IS NULL OR a.date >= p_from)
     AND (p_to IS NULL OR a.date <= p_to)
   ORDER BY a.date DESC
   LIMIT p_limit OFFSET COALESCE(p_offset,0);
$$;

CREATE OR REPLACE FUNCTION fn_attendance_update(
  p_id INT, p_user_id INT, p_subject_id INT, p_slot_id INT, p_set_slot BOOLEAN,
  p_date DATE, p_status TEXT, p_note TEXT, p_set_note BOOLEAN
) RETURNS SETOF attendance_records LANGUAGE sql AS $$
  UPDATE attendance_records a
     SET subject_id = p_subject_id,
         slot_id = CASE WHEN p_set_slot THEN p_slot_id ELSE a.slot_id END,
         date = p_date,
         status = p_status,
         note = CASE WHEN p_set_note THEN p_note ELSE a.note END
    FROM subjects s
   WHERE a.id = p_id AND a.subject_id = s.id AND s.user_id = p_user_id
   RETURNING a.*;
$$;

CREATE OR REPLACE FUNCTION fn_attendance_delete(p_id INT, p_user_id INT)
RETURNS INTEGER LANGUAGE sql AS $$
  WITH d AS (
    DELETE FROM attendance_records a USING subjects s
     WHERE a.id = p_id AND a.subject_id = s.id AND s.user_id = p_user_id RETURNING a.id
  ) SELECT COUNT(*)::int FROM d;
$$;

CREATE OR REPLACE FUNCTION fn_attendance_summary(p_user_id INT)
RETURNS TABLE (
  id INT, code TEXT, title TEXT, color TEXT,
  present INT, absent INT, late INT, cancelled INT
) LANGUAGE sql STABLE AS $$
  SELECT s.id, s.code, s.title, s.color,
         SUM(CASE WHEN a.status = 'present'   THEN 1 ELSE 0 END)::int AS present,
         SUM(CASE WHEN a.status = 'absent'    THEN 1 ELSE 0 END)::int AS absent,
         SUM(CASE WHEN a.status = 'late'      THEN 1 ELSE 0 END)::int AS late,
         SUM(CASE WHEN a.status = 'cancelled' THEN 1 ELSE 0 END)::int AS cancelled
    FROM subjects s LEFT JOIN attendance_records a ON a.subject_id = s.id
   WHERE s.user_id = p_user_id
   GROUP BY s.id, s.code, s.title, s.color
   ORDER BY s.code;
$$;

-- =========================
-- SCHOOL WORKS
-- =========================
CREATE OR REPLACE FUNCTION fn_work_list(
  p_user_id INT, p_status TEXT DEFAULT NULL, p_subject_id INT DEFAULT NULL, p_due_before DATE DEFAULT NULL,
  p_limit INT DEFAULT NULL, p_offset INT DEFAULT NULL
) RETURNS TABLE (
  id INT, user_id INT, subject_id INT, title TEXT, type TEXT, due_at TIMESTAMPTZ, priority TEXT, status TEXT, notes TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT, color TEXT
) LANGUAGE sql STABLE AS $$
  SELECT w.id, w.user_id, w.subject_id, w.title, w.type, w.due_at, w.priority, w.status, w.notes, w.created_at, w.updated_at,
         s.code, s.title, s.color
    FROM school_works w LEFT JOIN subjects s ON s.id = w.subject_id
   WHERE w.user_id = p_user_id
     AND (p_status IS NULL OR w.status = p_status)
     AND (p_subject_id IS NULL OR w.subject_id = p_subject_id)
     AND (p_due_before IS NULL OR (w.due_at IS NOT NULL AND w.due_at::date <= p_due_before))
   ORDER BY (w.status = 'done'), COALESCE(w.due_at, '9999-12-31'::timestamptz)
   LIMIT p_limit OFFSET COALESCE(p_offset,0);
$$;

CREATE OR REPLACE FUNCTION fn_work_create(
  p_user_id INT, p_subject_id INT, p_title TEXT, p_type TEXT, p_due_at TIMESTAMPTZ, p_priority TEXT, p_status TEXT, p_notes TEXT
) RETURNS TABLE (
  id INT, user_id INT, subject_id INT, title TEXT, type TEXT, due_at TIMESTAMPTZ, priority TEXT, status TEXT, notes TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT, color TEXT
) LANGUAGE sql AS $$
  WITH inserted AS (
    INSERT INTO school_works (user_id, subject_id, title, type, due_at, priority, status, notes)
    VALUES (p_user_id, p_subject_id, p_title, COALESCE(p_type,'assignment'), p_due_at, COALESCE(p_priority,'medium'), COALESCE(p_status,'todo'), p_notes)
    RETURNING *
  )
  SELECT i.id, i.user_id, i.subject_id, i.title, i.type, i.due_at, i.priority, i.status, i.notes, i.created_at, i.updated_at,
         s.code, s.title, s.color
    FROM inserted i LEFT JOIN subjects s ON s.id = i.subject_id;
$$;

CREATE OR REPLACE FUNCTION fn_work_get(p_id INT, p_user_id INT)
RETURNS TABLE (
  id INT, user_id INT, subject_id INT, title TEXT, type TEXT, due_at TIMESTAMPTZ, priority TEXT, status TEXT, notes TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT, color TEXT
) LANGUAGE sql STABLE AS $$
  SELECT w.id, w.user_id, w.subject_id, w.title, w.type, w.due_at, w.priority, w.status, w.notes, w.created_at, w.updated_at,
         s.code, s.title, s.color
    FROM school_works w LEFT JOIN subjects s ON s.id = w.subject_id
   WHERE w.id = p_id AND w.user_id = p_user_id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_work_update(
  p_id INT, p_user_id INT, p_subject_id INT, p_set_subject BOOLEAN, p_title TEXT, p_type TEXT,
  p_due_at TIMESTAMPTZ, p_set_due BOOLEAN, p_priority TEXT, p_status TEXT, p_notes TEXT, p_set_notes BOOLEAN
) RETURNS TABLE (
  id INT, user_id INT, subject_id INT, title TEXT, type TEXT, due_at TIMESTAMPTZ, priority TEXT, status TEXT, notes TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT, color TEXT
) LANGUAGE sql AS $$
  WITH updated AS (
    UPDATE school_works w
       SET subject_id = CASE WHEN p_set_subject THEN p_subject_id ELSE w.subject_id END,
           title = p_title, type = p_type,
           due_at = CASE WHEN p_set_due THEN p_due_at ELSE w.due_at END,
           priority = p_priority, status = p_status,
           notes = CASE WHEN p_set_notes THEN p_notes ELSE w.notes END,
           updated_at = NOW()
     WHERE w.id = p_id AND w.user_id = p_user_id
     RETURNING w.*
  )
  SELECT u.id, u.user_id, u.subject_id, u.title, u.type, u.due_at, u.priority, u.status, u.notes, u.created_at, u.updated_at,
         s.code, s.title, s.color
    FROM updated u LEFT JOIN subjects s ON s.id = u.subject_id;
$$;

CREATE OR REPLACE FUNCTION fn_work_update_status(p_id INT, p_user_id INT, p_status TEXT)
RETURNS TABLE (
  id INT, user_id INT, subject_id INT, title TEXT, type TEXT, due_at TIMESTAMPTZ, priority TEXT, status TEXT, notes TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT, color TEXT
) LANGUAGE sql AS $$
  WITH updated AS (
    UPDATE school_works w SET status = p_status, updated_at = NOW()
     WHERE w.id = p_id AND w.user_id = p_user_id RETURNING w.*
  )
  SELECT u.id, u.user_id, u.subject_id, u.title, u.type, u.due_at, u.priority, u.status, u.notes, u.created_at, u.updated_at,
         s.code, s.title, s.color
    FROM updated u LEFT JOIN subjects s ON s.id = u.subject_id;
$$;

CREATE OR REPLACE FUNCTION fn_work_delete(p_id INT, p_user_id INT)
RETURNS INTEGER LANGUAGE sql AS $$
  WITH d AS (DELETE FROM school_works WHERE id = p_id AND user_id = p_user_id RETURNING id)
  SELECT COUNT(*)::int FROM d;
$$;

-- =========================
-- NOTES
-- =========================
CREATE OR REPLACE FUNCTION fn_note_list(
  p_user_id INT, p_search TEXT DEFAULT NULL, p_tag TEXT DEFAULT NULL, p_pinned BOOLEAN DEFAULT NULL,
  p_subject_id INT DEFAULT NULL, p_limit INT DEFAULT NULL, p_offset INT DEFAULT NULL
) RETURNS TABLE (
  id INT, user_id INT, subject_id INT, title TEXT, content TEXT, is_pinned BOOLEAN, color TEXT, tags TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT, subject_color TEXT
) LANGUAGE sql STABLE AS $$
  SELECT n.id, n.user_id, n.subject_id, n.title, n.content, n.is_pinned, n.color, n.tags, n.created_at, n.updated_at,
         s.code, s.title, s.color
    FROM notes n LEFT JOIN subjects s ON s.id = n.subject_id AND s.user_id = n.user_id
   WHERE n.user_id = p_user_id
     AND (p_subject_id IS NULL OR n.subject_id = p_subject_id)
     AND (p_pinned IS NULL OR n.is_pinned = p_pinned)
     AND (p_tag IS NULL OR n.tags ILIKE '%' || replace(replace(replace(p_tag,'\','\\'),'%','\%'),'_','\_') || '%' ESCAPE '\')
     AND (p_search IS NULL OR (
          n.title ILIKE '%' || replace(replace(replace(p_search,'\','\\'),'%','\%'),'_','\_') || '%' ESCAPE '\'
       OR n.content ILIKE '%' || replace(replace(replace(p_search,'\','\\'),'%','\%'),'_','\_') || '%' ESCAPE '\'))
   ORDER BY n.is_pinned DESC, n.updated_at DESC
   LIMIT p_limit OFFSET COALESCE(p_offset,0);
$$;

CREATE OR REPLACE FUNCTION fn_note_create(
  p_user_id INT, p_subject_id INT, p_title TEXT, p_content TEXT, p_is_pinned BOOLEAN, p_color TEXT, p_tags TEXT
) RETURNS TABLE (
  id INT, user_id INT, subject_id INT, title TEXT, content TEXT, is_pinned BOOLEAN, color TEXT, tags TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT, subject_color TEXT
) LANGUAGE sql AS $$
  WITH ins AS (
    INSERT INTO notes (user_id, subject_id, title, content, is_pinned, color, tags)
    VALUES (p_user_id, p_subject_id, COALESCE(p_title,'Untitled'), COALESCE(p_content,''), COALESCE(p_is_pinned,false), COALESCE(p_color,'#1C223D'), p_tags)
    RETURNING *
  )
  SELECT n.id, n.user_id, n.subject_id, n.title, n.content, n.is_pinned, n.color, n.tags, n.created_at, n.updated_at,
         s.code, s.title, s.color
    FROM ins n LEFT JOIN subjects s ON s.id = n.subject_id AND s.user_id = n.user_id;
$$;

CREATE OR REPLACE FUNCTION fn_note_get(p_id INT, p_user_id INT)
RETURNS TABLE (
  id INT, user_id INT, subject_id INT, title TEXT, content TEXT, is_pinned BOOLEAN, color TEXT, tags TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT, subject_color TEXT
) LANGUAGE sql STABLE AS $$
  SELECT n.id, n.user_id, n.subject_id, n.title, n.content, n.is_pinned, n.color, n.tags, n.created_at, n.updated_at,
         s.code, s.title, s.color
    FROM notes n LEFT JOIN subjects s ON s.id = n.subject_id AND s.user_id = n.user_id
   WHERE n.id = p_id AND n.user_id = p_user_id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_note_update(
  p_id INT, p_user_id INT, p_subject_id INT, p_set_subject BOOLEAN, p_title TEXT, p_content TEXT,
  p_is_pinned BOOLEAN, p_color TEXT, p_set_color BOOLEAN, p_tags TEXT, p_set_tags BOOLEAN
) RETURNS TABLE (
  id INT, user_id INT, subject_id INT, title TEXT, content TEXT, is_pinned BOOLEAN, color TEXT, tags TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT, subject_color TEXT
) LANGUAGE sql AS $$
  WITH upd AS (
    UPDATE notes n
       SET subject_id = CASE WHEN p_set_subject THEN p_subject_id ELSE n.subject_id END,
           title = p_title, content = p_content, is_pinned = p_is_pinned,
           color = CASE WHEN p_set_color THEN p_color ELSE n.color END,
           tags = CASE WHEN p_set_tags THEN p_tags ELSE n.tags END,
           updated_at = NOW()
     WHERE n.id = p_id AND n.user_id = p_user_id
     RETURNING n.*
  )
  SELECT n.id, n.user_id, n.subject_id, n.title, n.content, n.is_pinned, n.color, n.tags, n.created_at, n.updated_at,
         s.code, s.title, s.color
    FROM upd n LEFT JOIN subjects s ON s.id = n.subject_id AND s.user_id = n.user_id;
$$;

CREATE OR REPLACE FUNCTION fn_note_toggle_pin(p_id INT, p_user_id INT)
RETURNS TABLE (
  id INT, user_id INT, subject_id INT, title TEXT, content TEXT, is_pinned BOOLEAN, color TEXT, tags TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT, subject_color TEXT
) LANGUAGE sql AS $$
  WITH upd AS (
    UPDATE notes n SET is_pinned = NOT n.is_pinned, updated_at = NOW()
     WHERE n.id = p_id AND n.user_id = p_user_id RETURNING n.*
  )
  SELECT n.id, n.user_id, n.subject_id, n.title, n.content, n.is_pinned, n.color, n.tags, n.created_at, n.updated_at,
         s.code, s.title, s.color
    FROM upd n LEFT JOIN subjects s ON s.id = n.subject_id AND s.user_id = n.user_id;
$$;

CREATE OR REPLACE FUNCTION fn_note_delete(p_id INT, p_user_id INT)
RETURNS INTEGER LANGUAGE sql AS $$
  WITH d AS (DELETE FROM notes WHERE id = p_id AND user_id = p_user_id RETURNING id)
  SELECT COUNT(*)::int FROM d;
$$;

-- =========================
-- DASHBOARD
-- =========================
CREATE OR REPLACE FUNCTION fn_dashboard_classes(p_user_id INT, p_day_of_week INT)
RETURNS TABLE (
  id INT, start_time TIME, end_time TIME, room TEXT, modality TEXT,
  subject_id INT, code TEXT, title TEXT, color TEXT
) LANGUAGE sql STABLE AS $$
  SELECT sc.id, sc.start_time, sc.end_time, sc.room, sc.modality,
         s.id AS subject_id, s.code, s.title, s.color
    FROM schedule_slots sc JOIN subjects s ON s.id = sc.subject_id
   WHERE s.user_id = p_user_id AND sc.day_of_week = p_day_of_week
   ORDER BY sc.start_time;
$$;

CREATE OR REPLACE FUNCTION fn_dashboard_due_soon(p_user_id INT, p_today DATE)
RETURNS TABLE (
  id INT, title TEXT, type TEXT, due_at TIMESTAMPTZ, priority TEXT, status TEXT,
  subject_code TEXT, color TEXT
) LANGUAGE sql STABLE AS $$
  SELECT w.id, w.title, w.type, w.due_at, w.priority, w.status, s.code AS subject_code, s.color
    FROM school_works w LEFT JOIN subjects s ON s.id = w.subject_id
   WHERE w.user_id = p_user_id AND w.status != 'done' AND w.due_at IS NOT NULL
     AND w.due_at::date <= p_today + INTERVAL '7 days'
   ORDER BY w.due_at;
$$;

-- =========================
-- STUDY
-- =========================
CREATE OR REPLACE FUNCTION fn_study_sessions_list(p_user_id INT)
RETURNS TABLE (
  id INT, subject_id INT, duration_minutes INT, mode TEXT, notes TEXT, completed_at TIMESTAMPTZ,
  subject_code TEXT, subject_color TEXT
) LANGUAGE sql STABLE AS $$
  SELECT st.id, st.subject_id, st.duration_minutes, st.mode, st.notes, st.completed_at,
         s.code, s.color
    FROM study_sessions st LEFT JOIN subjects s ON s.id = st.subject_id
   WHERE st.user_id = p_user_id
   ORDER BY st.completed_at DESC LIMIT 50;
$$;

CREATE OR REPLACE FUNCTION fn_study_session_create(p_user_id INT, p_subject_id INT, p_duration INT, p_mode TEXT, p_notes TEXT)
RETURNS TABLE (
  id INT, subject_id INT, duration_minutes INT, mode TEXT, notes TEXT, completed_at TIMESTAMPTZ,
  subject_code TEXT, subject_color TEXT
) LANGUAGE sql AS $$
  WITH ins AS (
    INSERT INTO study_sessions (user_id, subject_id, duration_minutes, mode, notes)
    VALUES (p_user_id, p_subject_id, p_duration, p_mode, p_notes) RETURNING *
  )
  SELECT st.id, st.subject_id, st.duration_minutes, st.mode, st.notes, st.completed_at,
         s.code, s.color
    FROM ins st LEFT JOIN subjects s ON s.id = st.subject_id;
$$;

CREATE OR REPLACE FUNCTION fn_study_session_owned(p_id INT, p_user_id INT)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS(SELECT 1 FROM study_sessions WHERE id = p_id AND user_id = p_user_id);
$$;

CREATE OR REPLACE FUNCTION fn_study_stats_today(p_user_id INT, p_tz TEXT)
RETURNS INT LANGUAGE sql STABLE AS $$
  SELECT COALESCE(SUM(duration_minutes),0)::int FROM study_sessions
   WHERE user_id = p_user_id AND completed_at::date = (NOW() AT TIME ZONE p_tz)::date;
$$;

CREATE OR REPLACE FUNCTION fn_study_stats_week(p_user_id INT, p_tz TEXT)
RETURNS TABLE(minutes INT, sessions INT) LANGUAGE sql STABLE AS $$
  SELECT COALESCE(SUM(duration_minutes),0)::int, COUNT(*)::int
    FROM study_sessions
   WHERE user_id = p_user_id AND completed_at::date >= ((NOW() AT TIME ZONE p_tz)::date - INTERVAL '6 days');
$$;

CREATE OR REPLACE FUNCTION fn_study_stats_all(p_user_id INT)
RETURNS TABLE(sessions INT, minutes INT) LANGUAGE sql STABLE AS $$
  SELECT COUNT(*)::int, COALESCE(SUM(duration_minutes),0)::int FROM study_sessions WHERE user_id = p_user_id;
$$;

CREATE OR REPLACE FUNCTION fn_study_stats_by_subject(p_user_id INT)
RETURNS TABLE(subject_id INT, code TEXT, color TEXT, minutes INT) LANGUAGE sql STABLE AS $$
  SELECT s.id, s.code, s.color, COALESCE(SUM(st.duration_minutes),0)::int
    FROM study_sessions st JOIN subjects s ON s.id = st.subject_id
   WHERE st.user_id = p_user_id GROUP BY s.id, s.code, s.color ORDER BY minutes DESC;
$$;

CREATE OR REPLACE FUNCTION fn_study_active_days(p_user_id INT, p_tz TEXT)
RETURNS TABLE(day TEXT) LANGUAGE sql STABLE AS $$
  SELECT DISTINCT (completed_at AT TIME ZONE p_tz)::date::text AS day
    FROM study_sessions WHERE user_id = p_user_id ORDER BY day DESC LIMIT 60;
$$;

-- =========================
-- GRADES
-- =========================
CREATE OR REPLACE FUNCTION fn_grades_list(p_user_id INT)
RETURNS TABLE (
  id INT, subject_id INT, component_name TEXT, weight_pct NUMERIC, score_pct NUMERIC, target_pct NUMERIC, created_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT
) LANGUAGE sql STABLE AS $$
  SELECT g.id, g.subject_id, g.component_name, g.weight_pct, g.score_pct, g.target_pct, g.created_at,
         s.code, s.title
    FROM subject_grades g JOIN subjects s ON s.id = g.subject_id
   WHERE g.user_id = p_user_id ORDER BY s.code, g.component_name;
$$;

CREATE OR REPLACE FUNCTION fn_grade_get(p_id INT, p_user_id INT)
RETURNS TABLE (
  id INT, subject_id INT, component_name TEXT, weight_pct NUMERIC, score_pct NUMERIC, target_pct NUMERIC, created_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT
) LANGUAGE sql STABLE AS $$
  SELECT g.id, g.subject_id, g.component_name, g.weight_pct, g.score_pct, g.target_pct, g.created_at,
         s.code, s.title
    FROM subject_grades g JOIN subjects s ON s.id = g.subject_id
   WHERE g.id = p_id AND g.user_id = p_user_id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_grade_create(p_user_id INT, p_subject_id INT, p_component TEXT, p_weight NUMERIC, p_score NUMERIC, p_target NUMERIC)
RETURNS TABLE (
  id INT, subject_id INT, component_name TEXT, weight_pct NUMERIC, score_pct NUMERIC, target_pct NUMERIC, created_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT
) LANGUAGE sql AS $$
  WITH ins AS (
    INSERT INTO subject_grades (user_id, subject_id, component_name, weight_pct, score_pct, target_pct)
    VALUES (p_user_id, p_subject_id, p_component, p_weight, p_score, COALESCE(p_target,85)) RETURNING *
  )
  SELECT g.id, g.subject_id, g.component_name, g.weight_pct, g.score_pct, g.target_pct, g.created_at, s.code, s.title
    FROM ins g JOIN subjects s ON s.id = g.subject_id;
$$;

CREATE OR REPLACE FUNCTION fn_grade_owned(p_id INT, p_user_id INT)
RETURNS SETOF subject_grades LANGUAGE sql STABLE AS $$
  SELECT * FROM subject_grades WHERE id = p_id AND user_id = p_user_id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_grade_update(p_id INT, p_user_id INT, p_component TEXT, p_weight NUMERIC, p_score NUMERIC, p_set_score BOOLEAN, p_target NUMERIC)
RETURNS TABLE (
  id INT, subject_id INT, component_name TEXT, weight_pct NUMERIC, score_pct NUMERIC, target_pct NUMERIC, created_at TIMESTAMPTZ,
  subject_code TEXT, subject_title TEXT
) LANGUAGE sql AS $$
  WITH upd AS (
    UPDATE subject_grades g SET component_name = p_component, weight_pct = p_weight,
      score_pct = CASE WHEN p_set_score THEN p_score ELSE g.score_pct END, target_pct = p_target
     WHERE g.id = p_id AND g.user_id = p_user_id RETURNING *
  )
  SELECT g.id, g.subject_id, g.component_name, g.weight_pct, g.score_pct, g.target_pct, g.created_at, s.code, s.title
    FROM upd g JOIN subjects s ON s.id = g.subject_id;
$$;

CREATE OR REPLACE FUNCTION fn_grade_summary_subjects(p_user_id INT)
RETURNS TABLE(id INT, code TEXT, title TEXT, units INT, color TEXT) LANGUAGE sql STABLE AS $$
  SELECT id, code, title, units, color FROM subjects WHERE user_id = p_user_id ORDER BY code;
$$;

CREATE OR REPLACE FUNCTION fn_grade_summary_grades(p_user_id INT)
RETURNS SETOF subject_grades LANGUAGE sql STABLE AS $$
  SELECT * FROM subject_grades WHERE user_id = p_user_id;
$$;

-- =========================
-- ATTACHMENTS
-- =========================
CREATE OR REPLACE FUNCTION fn_attachment_add(p_user_id INT, p_resource_type TEXT, p_resource_id INT, p_original TEXT, p_stored TEXT, p_mime TEXT, p_size INT)
RETURNS SETOF attachments LANGUAGE sql AS $$
  INSERT INTO attachments (user_id, resource_type, resource_id, original_name, stored_name, mime_type, size_bytes)
  VALUES (p_user_id, p_resource_type, p_resource_id, p_original, p_stored, p_mime, p_size) RETURNING *;
$$;

CREATE OR REPLACE FUNCTION fn_attachment_list_resource(p_user_id INT, p_resource_type TEXT, p_resource_id INT)
RETURNS SETOF attachments LANGUAGE sql STABLE AS $$
  SELECT * FROM attachments WHERE user_id = p_user_id AND resource_type = p_resource_type AND resource_id = p_resource_id
   ORDER BY created_at, id;
$$;

CREATE OR REPLACE FUNCTION fn_attachment_list_all(p_user_id INT, p_resource_type TEXT)
RETURNS SETOF attachments LANGUAGE sql STABLE AS $$
  SELECT a.* FROM attachments a
   JOIN school_works r ON p_resource_type = 'work' AND r.id = a.resource_id AND r.user_id = a.user_id
   WHERE a.user_id = p_user_id AND a.resource_type = p_resource_type
  UNION ALL
  SELECT a.* FROM attachments a
   JOIN notes r ON p_resource_type = 'note' AND r.id = a.resource_id AND r.user_id = a.user_id
   WHERE a.user_id = p_user_id AND a.resource_type = p_resource_type
   ORDER BY created_at, id;
$$;

CREATE OR REPLACE FUNCTION fn_attachment_get_owned(p_user_id INT, p_id INT)
RETURNS SETOF attachments LANGUAGE sql STABLE AS $$
  SELECT a.* FROM attachments a
   WHERE a.id = p_id AND a.user_id = p_user_id
     AND (
       (a.resource_type = 'work' AND EXISTS(SELECT 1 FROM school_works w WHERE w.id = a.resource_id AND w.user_id = a.user_id))
       OR (a.resource_type = 'note' AND EXISTS(SELECT 1 FROM notes n WHERE n.id = a.resource_id AND n.user_id = a.user_id))
     )
   LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_attachment_delete(p_user_id INT, p_id INT)
RETURNS SETOF attachments LANGUAGE sql AS $$
  DELETE FROM attachments WHERE id = p_id AND user_id = p_user_id RETURNING *;
$$;

CREATE OR REPLACE FUNCTION fn_attachment_select_for_resource(p_user_id INT, p_resource_type TEXT, p_resource_id INT)
RETURNS SETOF attachments LANGUAGE sql STABLE AS $$
  SELECT * FROM attachments WHERE user_id = p_user_id AND resource_type = p_resource_type AND resource_id = p_resource_id;
$$;

CREATE OR REPLACE FUNCTION fn_attachment_delete_for_resource(p_user_id INT, p_resource_type TEXT, p_resource_id INT)
RETURNS SETOF attachments LANGUAGE sql AS $$
  DELETE FROM attachments WHERE user_id = p_user_id AND resource_type = p_resource_type AND resource_id = p_resource_id RETURNING *;
$$;

-- =========================
-- RECYCLE BIN
-- =========================
CREATE OR REPLACE FUNCTION fn_recycle_purge_expired(p_user_id INT DEFAULT NULL)
RETURNS TABLE(user_id INT, item_type TEXT, payload_json JSONB) LANGUAGE sql AS $$
  DELETE FROM recycle_bin rb
   WHERE rb.expires_at <= NOW() AND (p_user_id IS NULL OR rb.user_id = p_user_id)
  RETURNING rb.user_id, rb.item_type, rb.payload_json;
$$;

CREATE OR REPLACE FUNCTION fn_recycle_list(p_user_id INT)
RETURNS TABLE(id INT, type TEXT, label TEXT, "deletedAt" TIMESTAMPTZ, "expiresAt" TIMESTAMPTZ) LANGUAGE sql STABLE AS $$
  SELECT rb.id, rb.item_type, rb.label, rb.deleted_at, rb.expires_at
    FROM recycle_bin rb WHERE rb.user_id = p_user_id ORDER BY rb.deleted_at DESC;
$$;

CREATE OR REPLACE FUNCTION fn_recycle_get(p_user_id INT, p_id INT)
RETURNS SETOF recycle_bin LANGUAGE sql STABLE AS $$
  SELECT * FROM recycle_bin WHERE id = p_id AND user_id = p_user_id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_recycle_delete(p_user_id INT, p_id INT)
RETURNS SETOF recycle_bin LANGUAGE sql AS $$
  DELETE FROM recycle_bin WHERE id = p_id AND user_id = p_user_id RETURNING *;
$$;

CREATE OR REPLACE FUNCTION fn_recycle_trash(p_user_id INT, p_type TEXT, p_id INT)
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE
  v_bin_id INT;
  v_subject subjects%ROWTYPE;
  v_note notes%ROWTYPE;
  v_task school_works%ROWTYPE;
  v_session study_sessions%ROWTYPE;
  v_grade subject_grades%ROWTYPE;
  v_slot schedule_slots%ROWTYPE;
  v_att attendance_records%ROWTYPE;
  v_payload JSONB;
  v_label TEXT;
  v_code TEXT;
BEGIN
  DELETE FROM recycle_bin WHERE expires_at <= NOW() AND user_id = p_user_id;
  IF p_type = 'subject' THEN
    SELECT * INTO v_subject FROM subjects WHERE id = p_id AND user_id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND:Subject not found'; END IF;
    v_payload := jsonb_build_object(
      'subject', to_jsonb(v_subject),
      'schedule', COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT * FROM schedule_slots WHERE subject_id = p_id) x), '[]'::jsonb),
      'attendance', COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT * FROM attendance_records WHERE subject_id = p_id) x), '[]'::jsonb),
      'grades', COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT * FROM subject_grades WHERE subject_id = p_id AND user_id = p_user_id) x), '[]'::jsonb),
      'tasks', COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT * FROM school_works WHERE subject_id = p_id AND user_id = p_user_id) x), '[]'::jsonb),
      'sessions', COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT * FROM study_sessions WHERE subject_id = p_id AND user_id = p_user_id) x), '[]'::jsonb),
      'notes', COALESCE((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT * FROM notes WHERE subject_id = p_id AND user_id = p_user_id) x), '[]'::jsonb)
    );
    v_label := v_subject.code || ' — ' || v_subject.title;
    INSERT INTO recycle_bin (user_id,item_type,label,payload_json,deleted_at,expires_at)
      VALUES (p_user_id,'subject',v_label,v_payload,NOW(),NOW()+INTERVAL '30 days') RETURNING id INTO v_bin_id;
    DELETE FROM school_works WHERE subject_id = p_id AND user_id = p_user_id;
    DELETE FROM study_sessions WHERE subject_id = p_id AND user_id = p_user_id;
    DELETE FROM notes WHERE subject_id = p_id AND user_id = p_user_id;
    DELETE FROM subjects WHERE id = p_id AND user_id = p_user_id;

  ELSIF p_type = 'note' THEN
    SELECT * INTO v_note FROM notes WHERE id = p_id AND user_id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND:Item not found'; END IF;
    INSERT INTO recycle_bin (user_id,item_type,label,payload_json,deleted_at,expires_at)
      VALUES (p_user_id,'note',COALESCE(v_note.title,'Note'),to_jsonb(v_note),NOW(),NOW()+INTERVAL '30 days') RETURNING id INTO v_bin_id;
    DELETE FROM notes WHERE id = p_id AND user_id = p_user_id;

  ELSIF p_type = 'task' THEN
    SELECT * INTO v_task FROM school_works WHERE id = p_id AND user_id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND:Item not found'; END IF;
    INSERT INTO recycle_bin (user_id,item_type,label,payload_json,deleted_at,expires_at)
      VALUES (p_user_id,'task',COALESCE(v_task.title,'Task'),to_jsonb(v_task),NOW(),NOW()+INTERVAL '30 days') RETURNING id INTO v_bin_id;
    DELETE FROM school_works WHERE id = p_id AND user_id = p_user_id;

  ELSIF p_type = 'session' THEN
    SELECT * INTO v_session FROM study_sessions WHERE id = p_id AND user_id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND:Item not found'; END IF;
    INSERT INTO recycle_bin (user_id,item_type,label,payload_json,deleted_at,expires_at)
      VALUES (p_user_id,'session','Study session ('||v_session.duration_minutes||' min)',to_jsonb(v_session),NOW(),NOW()+INTERVAL '30 days') RETURNING id INTO v_bin_id;
    DELETE FROM study_sessions WHERE id = p_id AND user_id = p_user_id;

  ELSIF p_type = 'grade' THEN
    SELECT * INTO v_grade FROM subject_grades WHERE id = p_id AND user_id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND:Item not found'; END IF;
    INSERT INTO recycle_bin (user_id,item_type,label,payload_json,deleted_at,expires_at)
      VALUES (p_user_id,'grade',COALESCE(v_grade.component_name,'Grade'),to_jsonb(v_grade),NOW(),NOW()+INTERVAL '30 days') RETURNING id INTO v_bin_id;
    DELETE FROM subject_grades WHERE id = p_id AND user_id = p_user_id;

  ELSIF p_type = 'schedule' THEN
    SELECT slot.* INTO v_slot FROM schedule_slots slot JOIN subjects sub ON sub.id = slot.subject_id
     WHERE slot.id = p_id AND sub.user_id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND:Item not found'; END IF;
    SELECT code INTO v_code FROM subjects WHERE id = v_slot.subject_id;
    INSERT INTO recycle_bin (user_id,item_type,label,payload_json,deleted_at,expires_at)
      VALUES (p_user_id,'schedule',COALESCE(v_code,'Course')||' timetable class',to_jsonb(v_slot),NOW(),NOW()+INTERVAL '30 days') RETURNING id INTO v_bin_id;
    DELETE FROM schedule_slots WHERE id = p_id;

  ELSIF p_type = 'attendance' THEN
    SELECT record.* INTO v_att FROM attendance_records record JOIN subjects sub ON sub.id = record.subject_id
     WHERE record.id = p_id AND sub.user_id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND:Item not found'; END IF;
    INSERT INTO recycle_bin (user_id,item_type,label,payload_json,deleted_at,expires_at)
      VALUES (p_user_id,'attendance',v_att.date::text||' attendance ('||v_att.status||')',to_jsonb(v_att),NOW(),NOW()+INTERVAL '30 days') RETURNING id INTO v_bin_id;
    DELETE FROM attendance_records WHERE id = p_id;

  ELSE
    RAISE EXCEPTION 'BAD_REQUEST:Unsupported recycle-bin item type';
  END IF;
  RETURN v_bin_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_recycle_restore(p_user_id INT, p_id INT)
RETURNS TABLE(id INT, type TEXT, label TEXT) LANGUAGE plpgsql AS $$
DECLARE
  v_item recycle_bin%ROWTYPE;
  v_payload JSONB;
  v_elem JSONB;
  v_row JSONB;
  v_table TEXT;
BEGIN
  DELETE FROM recycle_bin WHERE expires_at <= NOW() AND user_id = p_user_id;
  SELECT * INTO v_item FROM recycle_bin rb WHERE rb.id = p_id AND rb.user_id = p_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'NOT_FOUND:Recycle-bin item not found or expired'; END IF;
  v_payload := v_item.payload_json;

  IF v_item.item_type = 'subject' THEN
    INSERT INTO subjects SELECT * FROM jsonb_populate_record(NULL::subjects, v_payload->'subject') ON CONFLICT (id) DO NOTHING;
    FOR v_elem IN SELECT value FROM jsonb_array_elements(COALESCE(v_payload->'schedule','[]'::jsonb)) LOOP
      INSERT INTO schedule_slots SELECT * FROM jsonb_populate_record(NULL::schedule_slots, v_elem) ON CONFLICT (id) DO NOTHING;
    END LOOP;
    FOR v_elem IN SELECT value FROM jsonb_array_elements(COALESCE(v_payload->'attendance','[]'::jsonb)) LOOP
      v_row := v_elem;
      IF (v_row->>'slot_id') IS NOT NULL THEN
        IF NOT EXISTS(SELECT 1 FROM schedule_slots s WHERE s.id = (v_row->>'slot_id')::int) THEN
          v_row := jsonb_set(v_row, '{slot_id}', 'null'::jsonb);
        END IF;
      END IF;
      INSERT INTO attendance_records SELECT * FROM jsonb_populate_record(NULL::attendance_records, v_row) ON CONFLICT (id) DO NOTHING;
    END LOOP;
    FOR v_elem IN SELECT value FROM jsonb_array_elements(COALESCE(v_payload->'grades','[]'::jsonb)) LOOP
      INSERT INTO subject_grades SELECT * FROM jsonb_populate_record(NULL::subject_grades, v_elem) ON CONFLICT (id) DO NOTHING;
    END LOOP;
    FOR v_elem IN SELECT value FROM jsonb_array_elements(COALESCE(v_payload->'tasks','[]'::jsonb)) LOOP
      INSERT INTO school_works SELECT * FROM jsonb_populate_record(NULL::school_works, v_elem) ON CONFLICT (id) DO NOTHING;
    END LOOP;
    FOR v_elem IN SELECT value FROM jsonb_array_elements(COALESCE(v_payload->'sessions','[]'::jsonb)) LOOP
      INSERT INTO study_sessions SELECT * FROM jsonb_populate_record(NULL::study_sessions, v_elem) ON CONFLICT (id) DO NOTHING;
    END LOOP;
    FOR v_elem IN SELECT value FROM jsonb_array_elements(COALESCE(v_payload->'notes','[]'::jsonb)) LOOP
      INSERT INTO notes SELECT * FROM jsonb_populate_record(NULL::notes, v_elem) ON CONFLICT (id) DO NOTHING;
    END LOOP;
    PERFORM setval(pg_get_serial_sequence('subjects','id'), COALESCE((SELECT MAX(s.id) FROM subjects s),1));
    PERFORM setval(pg_get_serial_sequence('schedule_slots','id'), COALESCE((SELECT MAX(s.id) FROM schedule_slots s),1));
    PERFORM setval(pg_get_serial_sequence('attendance_records','id'), COALESCE((SELECT MAX(a.id) FROM attendance_records a),1));
    PERFORM setval(pg_get_serial_sequence('subject_grades','id'), COALESCE((SELECT MAX(g.id) FROM subject_grades g),1));
    PERFORM setval(pg_get_serial_sequence('school_works','id'), COALESCE((SELECT MAX(w.id) FROM school_works w),1));
    PERFORM setval(pg_get_serial_sequence('study_sessions','id'), COALESCE((SELECT MAX(s.id) FROM study_sessions s),1));
    PERFORM setval(pg_get_serial_sequence('notes','id'), COALESCE((SELECT MAX(n.id) FROM notes n),1));

  ELSIF v_item.item_type = 'note' THEN
    INSERT INTO notes SELECT * FROM jsonb_populate_record(NULL::notes, v_payload) ON CONFLICT (id) DO NOTHING;
    PERFORM setval(pg_get_serial_sequence('notes','id'), COALESCE((SELECT MAX(n.id) FROM notes n),1));
  ELSIF v_item.item_type = 'task' THEN
    INSERT INTO school_works SELECT * FROM jsonb_populate_record(NULL::school_works, v_payload) ON CONFLICT (id) DO NOTHING;
    PERFORM setval(pg_get_serial_sequence('school_works','id'), COALESCE((SELECT MAX(w.id) FROM school_works w),1));
  ELSIF v_item.item_type = 'session' THEN
    INSERT INTO study_sessions SELECT * FROM jsonb_populate_record(NULL::study_sessions, v_payload) ON CONFLICT (id) DO NOTHING;
    PERFORM setval(pg_get_serial_sequence('study_sessions','id'), COALESCE((SELECT MAX(s.id) FROM study_sessions s),1));
  ELSIF v_item.item_type = 'grade' THEN
    INSERT INTO subject_grades SELECT * FROM jsonb_populate_record(NULL::subject_grades, v_payload) ON CONFLICT (id) DO NOTHING;
    PERFORM setval(pg_get_serial_sequence('subject_grades','id'), COALESCE((SELECT MAX(g.id) FROM subject_grades g),1));
  ELSIF v_item.item_type = 'schedule' THEN
    INSERT INTO schedule_slots SELECT * FROM jsonb_populate_record(NULL::schedule_slots, v_payload) ON CONFLICT (id) DO NOTHING;
    PERFORM setval(pg_get_serial_sequence('schedule_slots','id'), COALESCE((SELECT MAX(s.id) FROM schedule_slots s),1));
  ELSIF v_item.item_type = 'attendance' THEN
    v_row := v_payload;
    IF (v_row->>'slot_id') IS NOT NULL THEN
      IF NOT EXISTS(SELECT 1 FROM schedule_slots s WHERE s.id = (v_row->>'slot_id')::int) THEN
        v_row := jsonb_set(v_row, '{slot_id}', 'null'::jsonb);
      END IF;
    END IF;
    INSERT INTO attendance_records SELECT * FROM jsonb_populate_record(NULL::attendance_records, v_row) ON CONFLICT (id) DO NOTHING;
    PERFORM setval(pg_get_serial_sequence('attendance_records','id'), COALESCE((SELECT MAX(a.id) FROM attendance_records a),1));
  ELSE
    RAISE EXCEPTION 'BAD_REQUEST:Unsupported recycle-bin item type';
  END IF;

  DELETE FROM recycle_bin rb WHERE rb.id = p_id;
  RETURN QUERY SELECT v_item.id, v_item.item_type, v_item.label;
END;
$$;

-- Attachment route helpers
CREATE OR REPLACE FUNCTION fn_attachment_resource_owned(p_resource_type TEXT, p_resource_id INT, p_user_id INT)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT CASE
    WHEN p_resource_type = 'work' THEN EXISTS(SELECT 1 FROM school_works WHERE id = p_resource_id AND user_id = p_user_id)
    WHEN p_resource_type = 'note' THEN EXISTS(SELECT 1 FROM notes WHERE id = p_resource_id AND user_id = p_user_id)
    ELSE FALSE
  END;
$$;

CREATE OR REPLACE FUNCTION fn_attachment_count(p_user_id INT, p_resource_type TEXT, p_resource_id INT)
RETURNS INT LANGUAGE sql STABLE AS $$
  SELECT COUNT(*)::int FROM attachments WHERE user_id = p_user_id AND resource_type = p_resource_type AND resource_id = p_resource_id;
$$;
