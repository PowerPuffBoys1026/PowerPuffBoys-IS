const express = require('express');
const { z } = require('zod');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { validate } = require('../utils/validate');
const { asyncHandler } = require('../utils/asyncHandler');
const { HttpError } = require('../utils/errors');
const recycleBin = require('../services/recycle_bin');
const { parseId } = require('../utils/parse');

const router = express.Router();
router.use(requireAuth);

const sessionSchema = z.object({
  subjectId: z.number().int().nullish(),
  durationMinutes: z.number().int().min(1).max(360),
  mode: z.enum(['focus', 'short_break', 'long_break', 'short', 'long']).default('focus'),
  notes: z.string().nullish(),
});

function normalizeMode(m) {
  if (m === 'short') return 'short_break';
  if (m === 'long') return 'long_break';
  return m || 'focus';
}

function toSession(row) {
  return {
    id: row.id,
    subjectId: row.subject_id,
    subjectCode: row.subject_code ?? null,
    subjectColor: row.subject_color ?? null,
    durationMinutes: row.duration_minutes,
    mode: row.mode,
    notes: row.notes,
    completedAt: row.completed_at,
  };
}

router.get('/sessions', asyncHandler(async (req, res) => {
  const rows = await db.query(
    `SELECT st.id, st.subject_id, st.duration_minutes, st.mode, st.notes, st.completed_at,
            s.code AS subject_code, s.color AS subject_color
       FROM study_sessions st
  LEFT JOIN subjects s ON s.id = st.subject_id
      WHERE st.user_id = $1
      ORDER BY st.completed_at DESC
      LIMIT 50`,
    [req.userId],
  );
  res.json({ data: rows.rows.map(toSession) });
}));

router.post('/sessions', asyncHandler(async (req, res) => {
  const data = validate(sessionSchema, req.body);
  if (data.subjectId != null) {
    const s = await db.query('SELECT id FROM subjects WHERE id = $1 AND user_id = $2', [data.subjectId, req.userId]);
    if (!s.rows[0]) throw new HttpError(404, 'Subject not found');
  }
  const ins = await db.query(
    `INSERT INTO study_sessions (user_id, subject_id, duration_minutes, mode, notes)
     VALUES ($1,$2,$3,$4,$5) RETURNING id`,
    [req.userId, data.subjectId ?? null, data.durationMinutes, normalizeMode(data.mode), data.notes ?? null],
  );
  const row = await db.query(
    `SELECT st.id, st.subject_id, st.duration_minutes, st.mode, st.notes, st.completed_at,
            s.code AS subject_code, s.color AS subject_color
       FROM study_sessions st LEFT JOIN subjects s ON s.id = st.subject_id WHERE st.id = $1`,
    [ins.rows[0].id],
  );
  res.status(201).json({ data: toSession(row.rows[0]) });
}));

router.get('/stats', asyncHandler(async (req, res) => {
  const userId = req.userId;
  const totalToday = await db.query(
    `SELECT COALESCE(SUM(duration_minutes), 0)::int AS minutes FROM study_sessions
      WHERE user_id = $1 AND completed_at::date = (NOW() AT TIME ZONE $2)::date`,
    [userId, require('../config').appTimezone],
  );
  const totalThisWeek = await db.query(
    `SELECT COALESCE(SUM(duration_minutes), 0)::int AS minutes, COUNT(*)::int AS sessions
       FROM study_sessions WHERE user_id = $1 AND completed_at::date >= ((NOW() AT TIME ZONE $2)::date - INTERVAL '6 days')`,
    [userId, require('../config').appTimezone],
  );
  const allTime = await db.query(
    `SELECT COUNT(*)::int AS sessions, COALESCE(SUM(duration_minutes), 0)::int AS minutes FROM study_sessions WHERE user_id = $1`,
    [userId],
  );
  const bySubject = await db.query(
    `SELECT s.id AS subject_id, s.code, s.color, COALESCE(SUM(st.duration_minutes), 0)::int AS minutes
       FROM study_sessions st JOIN subjects s ON s.id = st.subject_id
      WHERE st.user_id = $1 GROUP BY s.id, s.code, s.color ORDER BY minutes DESC`,
    [userId],
  );
  const activeDays = await db.query(
    `SELECT DISTINCT (completed_at AT TIME ZONE $2)::date AS day FROM study_sessions WHERE user_id = $1
     ORDER BY day DESC LIMIT 60`,
    [userId, require('../config').appTimezone],
  );
  let streakDays = 0;
  const days = activeDays.rows.map(r => (r.day instanceof Date ? r.day.toISOString().slice(0,10) : String(r.day).slice(0,10)));
  if (days.length > 0) {
    const tz = require('../config').appTimezone;
    const todayRes = await db.query(`SELECT (NOW() AT TIME ZONE $1)::date::text AS today`, [tz]);
    const today = todayRes.rows[0].today;
    const yRes = await db.query(`SELECT ((NOW() AT TIME ZONE $1)::date - INTERVAL '1 day')::date::text AS y`, [tz]);
    const yesterday = yRes.rows[0].y;
    let check = days.includes(today) ? today : (days.includes(yesterday) ? yesterday : null);
    if (check) {
      let cur = new Date(check + 'T00:00:00Z');
      while (days.includes(cur.toISOString().slice(0,10))) {
        streakDays++;
        cur.setUTCDate(cur.getUTCDate() - 1);
      }
    }
  }

  res.json({
    data: {
      totalMinutesToday: totalToday.rows[0].minutes,
      totalMinutesThisWeek: totalThisWeek.rows[0].minutes,
      sessionsThisWeek: totalThisWeek.rows[0].sessions,
      totalSessionsAllTime: allTime.rows[0].sessions,
      allTimeMinutes: allTime.rows[0].minutes,
      streakDays,
      bySubject: bySubject.rows.map((r) => ({ subjectId: r.subject_id, code: r.code, color: r.color, minutes: r.minutes })),
    },
  });
}));

router.delete('/sessions/:id', asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const cur = await db.query('SELECT id FROM study_sessions WHERE id = $1 AND user_id = $2', [id, req.userId]);
  if (!cur.rows[0]) throw new HttpError(404, 'Session not found');
  const recycleBinId = await recycleBin.trashRecord(req.userId, 'session', id);
  res.json({ data: { success: true, recycleBinId } });
}));

module.exports = router;
