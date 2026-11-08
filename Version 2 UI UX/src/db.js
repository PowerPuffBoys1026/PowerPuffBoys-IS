const fs = require('node:fs');
const path = require('node:path');
const Database = require('better-sqlite3');
const config = require('./config');

// Ensure the data directory exists before opening the file.
fs.mkdirSync(path.dirname(config.dbFile), { recursive: true });

const db = new Database(config.dbFile);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name     TEXT NOT NULL,
  student_no    TEXT,
  course        TEXT,
  year_level    TEXT,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS subjects (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code       TEXT NOT NULL,
  title      TEXT NOT NULL,
  instructor TEXT,
  instructor_email TEXT,
  office_hours TEXT,
  units      INTEGER NOT NULL DEFAULT 0,
  color      TEXT NOT NULL DEFAULT '#7B1E2B',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS schedule_slots (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_id  INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time  TEXT NOT NULL,
  end_time    TEXT NOT NULL,
  room        TEXT,
  modality    TEXT,
  building    TEXT,
  week_pattern TEXT NOT NULL DEFAULT 'every'
);

CREATE TABLE IF NOT EXISTS attendance_records (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  slot_id    INTEGER REFERENCES schedule_slots(id) ON DELETE SET NULL,
  date       TEXT NOT NULL,
  status     TEXT NOT NULL CHECK (status IN ('present','absent','late','cancelled')),
  note       TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS school_works (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
  title      TEXT NOT NULL,
  type       TEXT NOT NULL DEFAULT 'assignment',
  due_at     TEXT,
  priority   TEXT NOT NULL DEFAULT 'medium',
  status     TEXT NOT NULL DEFAULT 'todo',
  notes      TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS study_sessions (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id          INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id       INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
  duration_minutes INTEGER NOT NULL,
  mode             TEXT NOT NULL DEFAULT 'focus',
  notes            TEXT,
  completed_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS subject_notes (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
  title      TEXT NOT NULL,
  content    TEXT NOT NULL,
  tags       TEXT,
  is_pinned  INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS subject_grades (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id        INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id     INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  component_name TEXT NOT NULL,
  weight_pct     REAL NOT NULL DEFAULT 0,
  score_pct      REAL,
  target_pct     REAL DEFAULT 85,
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS recycle_bin (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_type    TEXT NOT NULL,
  label        TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  deleted_at   TEXT NOT NULL DEFAULT (datetime('now')),
  expires_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS attachments (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  resource_type TEXT NOT NULL CHECK (resource_type IN ('work', 'note')),
  resource_id   INTEGER NOT NULL,
  original_name TEXT NOT NULL,
  stored_name   TEXT NOT NULL UNIQUE,
  mime_type     TEXT NOT NULL,
  size_bytes    INTEGER NOT NULL CHECK (size_bytes >= 0),
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_subjects_user        ON subjects(user_id);
CREATE INDEX IF NOT EXISTS idx_slots_subject        ON schedule_slots(subject_id);
CREATE INDEX IF NOT EXISTS idx_attendance_subject   ON attendance_records(subject_id);
CREATE INDEX IF NOT EXISTS idx_works_user           ON school_works(user_id);
CREATE INDEX IF NOT EXISTS idx_works_due            ON school_works(due_at);
CREATE INDEX IF NOT EXISTS idx_study_user           ON study_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_user           ON subject_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_grades_user          ON subject_grades(user_id);
CREATE INDEX IF NOT EXISTS idx_recycle_user_expiry  ON recycle_bin(user_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_attachments_resource ON attachments(user_id, resource_type, resource_id);
`;

db.exec(SCHEMA);

function addColumnIfMissing(table, column, definition) {
  const columns = db.pragma(`table_info(${table})`);
  if (!columns.some((entry) => entry.name === column)) {
    db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
  }
}

addColumnIfMissing('subjects', 'instructor_email', 'TEXT');
addColumnIfMissing('subjects', 'office_hours', 'TEXT');
addColumnIfMissing('schedule_slots', 'building', 'TEXT');
addColumnIfMissing('schedule_slots', 'week_pattern', "TEXT NOT NULL DEFAULT 'every'");
addColumnIfMissing('users', 'year_level', 'TEXT');

module.exports = db;
