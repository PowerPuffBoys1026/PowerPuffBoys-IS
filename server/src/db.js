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
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS subjects (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code       TEXT NOT NULL,
  title      TEXT NOT NULL,
  instructor TEXT,
  units      INTEGER NOT NULL DEFAULT 0,
  color      TEXT NOT NULL DEFAULT '#4F46E5',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS schedule_slots (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_id  INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time  TEXT NOT NULL,
  end_time    TEXT NOT NULL,
  room        TEXT,
  modality    TEXT
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

CREATE TABLE IF NOT EXISTS notes (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title      TEXT NOT NULL DEFAULT 'Untitled',
  content    TEXT NOT NULL DEFAULT '',
  is_pinned  INTEGER NOT NULL DEFAULT 0,
  color      TEXT DEFAULT '#1C223D',
  tags       TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_subjects_user        ON subjects(user_id);
CREATE INDEX IF NOT EXISTS idx_slots_subject        ON schedule_slots(subject_id);
CREATE INDEX IF NOT EXISTS idx_attendance_subject   ON attendance_records(subject_id);
CREATE INDEX IF NOT EXISTS idx_works_user           ON school_works(user_id);
CREATE INDEX IF NOT EXISTS idx_works_due            ON school_works(due_at);
CREATE INDEX IF NOT EXISTS idx_notes_user           ON notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_updated        ON notes(updated_at);
`;

db.exec(SCHEMA);

module.exports = db;
