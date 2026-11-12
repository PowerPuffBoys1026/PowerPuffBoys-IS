-- v2 features: profile/schedule/subject extensions, notes-subject link, study/grades/recycle/attachments

ALTER TABLE users ADD COLUMN IF NOT EXISTS year_level TEXT;

ALTER TABLE subjects ADD COLUMN IF NOT EXISTS instructor_email TEXT;
ALTER TABLE subjects ADD COLUMN IF NOT EXISTS office_hours TEXT;

ALTER TABLE schedule_slots ADD COLUMN IF NOT EXISTS building TEXT;
ALTER TABLE schedule_slots ADD COLUMN IF NOT EXISTS week_pattern TEXT NOT NULL DEFAULT 'every';

-- Extend notes for subject-linked flashnotes (compatible with existing notes)
ALTER TABLE notes ADD COLUMN IF NOT EXISTS subject_id INTEGER REFERENCES subjects(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS study_sessions (
  id               SERIAL PRIMARY KEY,
  user_id          INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id       INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
  mode             TEXT NOT NULL DEFAULT 'focus',
  notes            TEXT,
  completed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subject_grades (
  id             SERIAL PRIMARY KEY,
  user_id        INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id     INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  component_name TEXT NOT NULL,
  weight_pct     NUMERIC(5,2) NOT NULL DEFAULT 0,
  score_pct      NUMERIC(5,2),
  target_pct     NUMERIC(5,2) DEFAULT 85,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS recycle_bin (
  id           SERIAL PRIMARY KEY,
  user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_type    TEXT NOT NULL,
  label        TEXT NOT NULL,
  payload_json JSONB NOT NULL,
  deleted_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at   TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS attachments (
  id            SERIAL PRIMARY KEY,
  user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  resource_type TEXT NOT NULL CHECK (resource_type IN ('work','note')),
  resource_id   INTEGER NOT NULL,
  original_name TEXT NOT NULL,
  stored_name   TEXT NOT NULL UNIQUE,
  mime_type     TEXT NOT NULL,
  size_bytes    INTEGER NOT NULL CHECK (size_bytes >= 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_study_user ON study_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_grades_user ON subject_grades(user_id);
CREATE INDEX IF NOT EXISTS idx_recycle_user_expiry ON recycle_bin(user_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_attachments_resource ON attachments(user_id, resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_notes_subject ON notes(subject_id);
