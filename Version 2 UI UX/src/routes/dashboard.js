const express = require('express');

const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { attendanceSummary } = require('../services/attendance');

const router = express.Router();
router.use(requireAuth);

const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function localDateString(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

// GET /api/dashboard/today
router.get('/today', (req, res) => {
  const now = new Date();
  const dayOfWeek = now.getDay();
  const today = localDateString(now);

  const classes = db
    .prepare(
      `SELECT sc.id, sc.start_time, sc.end_time, sc.room, sc.modality,
              s.id AS subject_id, s.code, s.title, s.color
         FROM schedule_slots sc
         JOIN subjects s ON s.id = sc.subject_id
        WHERE s.user_id = ? AND sc.day_of_week = ?
        ORDER BY sc.start_time`,
    )
    .all(req.userId, dayOfWeek)
    .map((row) => ({
      slotId: row.id,
      subjectId: row.subject_id,
      code: row.code,
      title: row.title,
      color: row.color,
      startTime: row.start_time,
      endTime: row.end_time,
      room: row.room,
      modality: row.modality,
    }));

  // Unfinished works due within the next 7 days (overdue items included).
  const dueSoon = db
    .prepare(
      `SELECT w.id, w.title, w.type, w.due_at, w.priority, w.status,
              s.code AS subject_code, s.color
         FROM school_works w
         LEFT JOIN subjects s ON s.id = w.subject_id
        WHERE w.user_id = ?
          AND w.status != 'done'
          AND w.due_at IS NOT NULL
          AND date(w.due_at) <= date(?, '+7 days')
        ORDER BY w.due_at`,
    )
    .all(req.userId, today)
    .map((row) => ({
      id: row.id,
      title: row.title,
      type: row.type,
      dueAt: row.due_at,
      priority: row.priority,
      status: row.status,
      subjectCode: row.subject_code,
      color: row.color,
      overdue: row.due_at.slice(0, 10) < today,
    }));

  const warnings = attendanceSummary(req.userId).filter((s) => s.warning);

  res.json({
    data: {
      date: today,
      dayName: DAY_NAMES[dayOfWeek],
      classes,
      dueSoon,
      attendanceWarnings: warnings,
    },
  });
});

module.exports = router;
