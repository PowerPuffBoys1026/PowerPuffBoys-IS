const express = require('express');
const { z } = require('zod');
const db = require('../db');
const config = require('../config');
const { requireAuth } = require('../middleware/auth');
const { validate } = require('../utils/validate');
const { asyncHandler } = require('../utils/asyncHandler');
const { HttpError } = require('../utils/errors');
const recycleBin = require('../services/recycle_bin');
const { parseId } = require('../utils/parse');
const { dateInTimeZone } = require('../utils/dates');

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
  const rows = await db.query('SELECT * FROM fn_study_sessions_list($1)', [req.userId]);
  res.json({ data: rows.rows.map(toSession) });
}));

router.post('/sessions', asyncHandler(async (req, res) => {
  const data = validate(sessionSchema, req.body);
  if (data.subjectId != null) {
    const s = await db.query('SELECT fn_subject_owned($1,$2) AS exists', [data.subjectId, req.userId]);
    if (!s.rows[0]?.exists) throw new HttpError(404, 'Subject not found');
  }
  const row = await db.query('SELECT * FROM fn_study_session_create($1,$2,$3,$4,$5)', [
    req.userId, data.subjectId ?? null, data.durationMinutes, normalizeMode(data.mode), data.notes ?? null,
  ]);
  res.status(201).json({ data: toSession(row.rows[0]) });
}));

router.get('/stats', asyncHandler(async (req, res) => {
  const userId = req.userId;
  const tz = config.appTimezone;
  const [totalToday, week, allTime, bySubject, activeDays] = await Promise.all([
    db.query('SELECT fn_study_stats_today($1,$2) AS minutes', [userId, tz]),
    db.query('SELECT * FROM fn_study_stats_week($1,$2)', [userId, tz]),
    db.query('SELECT * FROM fn_study_stats_all($1)', [userId]),
    db.query('SELECT * FROM fn_study_stats_by_subject($1)', [userId]),
    db.query('SELECT day FROM fn_study_active_days($1,$2)', [userId, tz]),
  ]);

  const days = activeDays.rows.map((r) => String(r.day).slice(0, 10));
  let streakDays = 0;
  if (days.length > 0) {
    const today = dateInTimeZone(new Date(), tz);
    const yDate = new Date(); yDate.setDate(yDate.getDate() - 1);
    const yesterday = dateInTimeZone(yDate, tz);
    let check = days.includes(today) ? today : (days.includes(yesterday) ? yesterday : null);
    if (check) {
      let cur = new Date(check + 'T00:00:00Z');
      while (days.includes(cur.toISOString().slice(0, 10))) {
        streakDays++;
        cur.setUTCDate(cur.getUTCDate() - 1);
      }
    }
  }

  res.json({
    data: {
      totalMinutesToday: totalToday.rows[0].minutes,
      totalMinutesThisWeek: week.rows[0]?.minutes ?? 0,
      sessionsThisWeek: week.rows[0]?.sessions ?? 0,
      totalSessionsAllTime: allTime.rows[0]?.sessions ?? 0,
      allTimeMinutes: allTime.rows[0]?.minutes ?? 0,
      streakDays,
      bySubject: bySubject.rows.map((r) => ({ subjectId: r.subject_id, code: r.code, color: r.color, minutes: r.minutes })),
    },
  });
}));

router.delete('/sessions/:id', asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const cur = await db.query('SELECT fn_study_session_owned($1,$2) AS exists', [id, req.userId]);
  if (!cur.rows[0]?.exists) throw new HttpError(404, 'Session not found');
  const recycleBinId = await recycleBin.trashRecord(req.userId, 'session', id);
  res.json({ data: { success: true, recycleBinId } });
}));

module.exports = router;
