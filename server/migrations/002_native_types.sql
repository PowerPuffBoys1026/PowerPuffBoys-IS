-- Move the columns that were originally stored as TEXT to real PostgreSQL
-- types. Existing values are all in ISO-8601 / 24h HH:MM format.
-- The checks keep this migration safe for databases that were converted by hand.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = current_schema()
       AND table_name = 'attendance_records'
       AND column_name = 'date'
       AND data_type <> 'date'
  ) THEN
    ALTER TABLE attendance_records
      ALTER COLUMN date TYPE date USING date::date;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = current_schema()
       AND table_name = 'schedule_slots'
       AND column_name IN ('start_time', 'end_time')
       AND data_type <> 'time without time zone'
  ) THEN
    ALTER TABLE schedule_slots
      ALTER COLUMN start_time TYPE time USING start_time::time,
      ALTER COLUMN end_time   TYPE time USING end_time::time;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = current_schema()
       AND table_name = 'school_works'
       AND column_name = 'due_at'
       AND data_type <> 'timestamp with time zone'
  ) THEN
    ALTER TABLE school_works
      ALTER COLUMN due_at TYPE timestamptz USING NULLIF(due_at, '')::timestamptz;
  END IF;
END $$;
