-- Database-enforced rules that mirror the API validation.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'schedule_slots_time_range'
       AND conrelid = 'schedule_slots'::regclass
  ) THEN
    ALTER TABLE schedule_slots
      ADD CONSTRAINT schedule_slots_time_range CHECK (start_time < end_time);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'school_works_type_check'
       AND conrelid = 'school_works'::regclass
  ) THEN
    ALTER TABLE school_works
      ADD CONSTRAINT school_works_type_check
      CHECK (type IN ('assignment', 'quiz', 'exam', 'project'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'school_works_priority_check'
       AND conrelid = 'school_works'::regclass
  ) THEN
    ALTER TABLE school_works
      ADD CONSTRAINT school_works_priority_check
      CHECK (priority IN ('low', 'medium', 'high'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'school_works_status_check'
       AND conrelid = 'school_works'::regclass
  ) THEN
    ALTER TABLE school_works
      ADD CONSTRAINT school_works_status_check
      CHECK (status IN ('todo', 'doing', 'done'));
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_subjects_user_code
  ON subjects (user_id, code);

CREATE INDEX IF NOT EXISTS idx_attendance_subject_date
  ON attendance_records (subject_id, date);

CREATE INDEX IF NOT EXISTS idx_works_user_status_due
  ON school_works (user_id, status, due_at);
