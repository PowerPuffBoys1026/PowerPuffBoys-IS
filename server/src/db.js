const { Pool } = require('pg');
const config = require('./config');

const pool = new Pool(config.databaseUrl
  ? { connectionString: config.databaseUrl }
  : {
      host: config.pgHost,
      port: config.pgPort,
      database: config.pgDatabase,
      user: config.pgUser,
      password: config.pgPassword,
    });

pool.on('error', (error) => {
  console.error('Unexpected PostgreSQL pool error:', error.message);
});

const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id            SERIAL PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name     TEXT NOT NULL,
  student_no    TEXT,
  course        TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subjects (
  id         SERIAL PRIMARY KEY,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code       TEXT NOT NULL,
  title      TEXT NOT NULL,
  instructor TEXT,
  units      INTEGER NOT NULL DEFAULT 0,
  color      TEXT NOT NULL DEFAULT '#4F46E5',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS schedule_slots (
  id          SERIAL PRIMARY KEY,
  subject_id  INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time  TEXT NOT NULL,
  end_time    TEXT NOT NULL,
  room        TEXT,
  modality    TEXT
);

CREATE TABLE IF NOT EXISTS attendance_records (
  id         SERIAL PRIMARY KEY,
  subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  slot_id    INTEGER REFERENCES schedule_slots(id) ON DELETE SET NULL,
  date       TEXT NOT NULL,
  status     TEXT NOT NULL CHECK (status IN ('present','absent','late','cancelled')),
  note       TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS school_works (
  id         SERIAL PRIMARY KEY,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
  title      TEXT NOT NULL,
  type       TEXT NOT NULL DEFAULT 'assignment',
  due_at     TEXT,
  priority   TEXT NOT NULL DEFAULT 'medium',
  status     TEXT NOT NULL DEFAULT 'todo',
  notes      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notes (
  id         SERIAL PRIMARY KEY,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title      TEXT NOT NULL DEFAULT 'Untitled',
  content    TEXT NOT NULL DEFAULT '',
  is_pinned  BOOLEAN NOT NULL DEFAULT FALSE,
  color      TEXT DEFAULT '#1C223D',
  tags       TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subjects_user        ON subjects(user_id);
CREATE INDEX IF NOT EXISTS idx_slots_subject        ON schedule_slots(subject_id);
CREATE INDEX IF NOT EXISTS idx_attendance_subject   ON attendance_records(subject_id);
CREATE INDEX IF NOT EXISTS idx_works_user           ON school_works(user_id);
CREATE INDEX IF NOT EXISTS idx_works_due            ON school_works(due_at);
CREATE INDEX IF NOT EXISTS idx_notes_user           ON notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_updated        ON notes(updated_at);

-- Keep the oldest row if old data already contains duplicates, then enforce
-- uniqueness at the database level so concurrent requests cannot race.
DELETE FROM attendance_records a
 USING attendance_records b
 WHERE a.id > b.id
   AND a.subject_id = b.subject_id
   AND a.date = b.date
   AND a.slot_id IS NOT DISTINCT FROM b.slot_id;

CREATE UNIQUE INDEX IF NOT EXISTS uq_attendance_slot
  ON attendance_records (subject_id, date, slot_id)
  WHERE slot_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_attendance_no_slot
  ON attendance_records (subject_id, date)
  WHERE slot_id IS NULL;
`;

async function initDb() {
  await pool.query(SCHEMA);
}

pool.initDb = initDb;

module.exports = pool;
