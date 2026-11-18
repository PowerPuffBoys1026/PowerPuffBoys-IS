-- Indexes for mobile-facing filters that are not covered by the existing
-- composite indexes in 001/003.
--
-- Deliberately NOT added:
--   * school_works (status, due_at) — already covered by idx_works_user_status_due
--   * attendance_records (subject_id, date) — already in 003
--   * recycle_bin (expires_at) — idx_recycle_user_expiry already leads with user_id
--     and all cleanup queries are user-scoped.

CREATE INDEX IF NOT EXISTS idx_attendance_date
  ON attendance_records (date);

CREATE INDEX IF NOT EXISTS idx_slots_day_of_week
  ON schedule_slots (day_of_week);
