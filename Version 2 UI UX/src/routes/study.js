const express = require('express');
const { z } = require('zod');

const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const recycleBin = require('../services/recycle_bin');

const router = express.Router();
router.use(requireAuth);

const sessionSchema = z.object({
  subjectId: z.number().int().nullish(),
  durationMinutes: z.number().int().min(1).max(360),
  mode: z.enum(['focus', 'short_break', 'long_break']).default('focus'),
  notes: z.string().nullish(),
});

function toSession(row) {
  return {
    id: row.id,
    subjectId: row.subject_id,
    subjectCode: row.subject_code,
    subjectColor: row.subject_color,
    durationMinutes: row.duration_minutes,
    mode: row.mode,
    notes: row.notes,
    completedAt: row.completed_at,
  };
}

// GET /api/study/sessions
router.get('/sessions', (req, res) => {
  const rows = db
    .prepare(
      `SELECT st.id, st.subject_id, st.duration_minutes, st.mode, st.notes, st.completed_at,
              s.code AS subject_code, s.color AS subject_color
         FROM study_sessions st
    LEFT JOIN subjects s ON s.id = st.subject_id
        WHERE st.user_id = ?
        ORDER BY st.completed_at DESC
        LIMIT 50`,
    )
    .all(req.userId);

  res.json({ data: rows.map(toSession) });
});

// POST /api/study/sessions
router.post('/sessions', (req, res) => {
  const data = validate(sessionSchema, req.body);

  if (data.subjectId) {
    const subject = db
      .prepare('SELECT id FROM subjects WHERE id = ? AND user_id = ?')
      .get(data.subjectId, req.userId);
    if (!subject) throw new HttpError(404, 'Subject not found');
  }

  const info = db
    .prepare(
      `INSERT INTO study_sessions (user_id, subject_id, duration_minutes, mode, notes)
       VALUES (?, ?, ?, ?, ?)`,
    )
    .run(req.userId, data.subjectId ?? null, data.durationMinutes, data.mode, data.notes ?? null);

  const row = db
    .prepare(
      `SELECT st.id, st.subject_id, st.duration_minutes, st.mode, st.notes, st.completed_at,
              s.code AS subject_code, s.color AS subject_color
         FROM study_sessions st
    LEFT JOIN subjects s ON s.id = st.subject_id
        WHERE st.id = ?`,
    )
    .get(info.lastInsertRowid);

  res.status(201).json({ data: toSession(row) });
});

// GET /api/study/stats
router.get('/stats', (req, res) => {
  const todayRow = db
    .prepare(
      `SELECT COALESCE(SUM(duration_minutes), 0) AS total_minutes
         FROM study_sessions
        WHERE user_id = ? AND date(completed_at) = date('now')`,
    )
    .get(req.userId);

  const weekRow = db
    .prepare(
      `SELECT COALESCE(SUM(duration_minutes), 0) AS total_minutes,
              COUNT(id) AS total_sessions
         FROM study_sessions
        WHERE user_id = ? AND date(completed_at) >= date('now', '-7 days')`,
    )
    .get(req.userId);

  const allRow = db
    .prepare(
      `SELECT COUNT(id) AS total_sessions, COALESCE(SUM(duration_minutes), 0) AS all_time_minutes
         FROM study_sessions
        WHERE user_id = ?`,
    )
    .get(req.userId);

  const bySubjectRows = db
    .prepare(
      `SELECT s.id AS subject_id, s.code, s.color,
              COALESCE(SUM(st.duration_minutes), 0) AS minutes
         FROM study_sessions st
         JOIN subjects s ON s.id = st.subject_id
        WHERE st.user_id = ?
        GROUP BY s.id
        ORDER BY minutes DESC`,
    )
    .all(req.userId);

  // Calculate streak days (consecutive days with at least 1 session)
  const distinctDays = db
    .prepare(
      `SELECT DISTINCT date(completed_at) AS day
         FROM study_sessions
        WHERE user_id = ?
        ORDER BY day DESC
        LIMIT 30`,
    )
    .all(req.userId)
    .map((r) => r.day);

  let streak = 0;
  const now = new Date();
  const todayStr = now.toISOString().slice(0, 10);
  let checkDate = new Date(now);

  // If student studied today or yesterday, check backward
  const hasToday = distinctDays.includes(todayStr);
  if (!hasToday) {
    checkDate.setDate(checkDate.getDate() - 1);
  }

  while (true) {
    const dStr = checkDate.toISOString().slice(0, 10);
    if (distinctDays.includes(dStr)) {
      streak += 1;
      checkDate.setDate(checkDate.getDate() - 1);
    } else {
      break;
    }
  }

  res.json({
    data: {
      totalMinutesToday: todayRow ? todayRow.total_minutes : 0,
      totalMinutesThisWeek: weekRow ? weekRow.total_minutes : 0,
      sessionsThisWeek: weekRow ? weekRow.total_sessions : 0,
      totalSessionsAllTime: allRow ? allRow.total_sessions : 0,
      allTimeMinutes: allRow ? allRow.all_time_minutes : 0,
      streakDays: streak,
      bySubject: bySubjectRows.map((r) => ({
        subjectId: r.subject_id,
        code: r.code,
        color: r.color,
        minutes: r.minutes,
      })),
    },
  });
});

// DELETE /api/study/sessions/:id
router.delete('/sessions/:id', (req, res) => {
  const session = db
    .prepare('SELECT id FROM study_sessions WHERE id = ? AND user_id = ?')
    .get(req.params.id, req.userId);
  if (!session) throw new HttpError(404, 'Session not found');

  const recycleBinId = recycleBin.trashRecord(req.userId, 'session', Number(req.params.id));
  res.json({ data: { success: true, recycleBinId } });
});

module.exports = router;
