const express = require('express');
const { z } = require('zod');

const db = require('../db');
const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const recycleBin = require('../services/recycle_bin');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

const timeRegex = /^([01]\d|2[0-3]):[0-5]\d$/;

const slotSchema = z.object({
  subjectId: z.number().int().positive(),
  dayOfWeek: z.number().int().min(0).max(6),
  startTime: z.string().regex(timeRegex, 'startTime must be HH:MM (24h)'),
  endTime: z.string().regex(timeRegex, 'endTime must be HH:MM (24h)'),
  room: z.string().nullish(),
  building: z.string().nullish(),
  modality: z.string().nullish(),
  weekPattern: z.enum(['every', 'a', 'b']).optional(),
});

const slotUpdateSchema = slotSchema.partial();

function toSlot(row) {
  return {
    id: row.id,
    subjectId: row.subject_id,
    subjectCode: row.subject_code,
    subjectTitle: row.subject_title,
    color: row.color,
    dayOfWeek: row.day_of_week,
    startTime: row.start_time,
    endTime: row.end_time,
    room: row.room,
    building: row.building,
    modality: row.modality,
    weekPattern: row.week_pattern ?? 'every',
  };
}

const SELECT_SLOT = `
  SELECT sc.*, s.code AS subject_code, s.title AS subject_title, s.color
    FROM schedule_slots sc
    JOIN subjects s ON s.id = sc.subject_id`;

function ownedSlot(id, userId) {
  const row = db.prepare(`${SELECT_SLOT} WHERE sc.id = ? AND s.user_id = ?`).get(id, userId);
  if (!row) throw new HttpError(404, 'Schedule slot not found');
  return row;
}

function ownedSubject(subjectId, userId) {
  const row = db.prepare('SELECT id FROM subjects WHERE id = ? AND user_id = ?').get(subjectId, userId);
  if (!row) throw new HttpError(404, 'Subject not found');
  return row;
}

// GET /api/schedule?day=0..6
router.get('/', (req, res) => {
  const { day } = req.query;
  const params = [req.userId];
  let sql = `${SELECT_SLOT} WHERE s.user_id = ?`;

  if (day !== undefined && day !== '') {
    const dayNum = Number(day);
    if (!Number.isInteger(dayNum) || dayNum < 0 || dayNum > 6) {
      throw new HttpError(400, 'day must be an integer between 0 and 6');
    }
    sql += ' AND sc.day_of_week = ?';
    params.push(dayNum);
  }

  sql += ' ORDER BY sc.day_of_week, sc.start_time';
  res.json({ data: db.prepare(sql).all(...params).map(toSlot) });
});

// POST /api/schedule
router.post('/', (req, res) => {
  const data = validate(slotSchema, req.body);
  ownedSubject(data.subjectId, req.userId);

  const info = db
    .prepare(
      'INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time, room, building, modality, week_pattern) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    )
    .run(
      data.subjectId,
      data.dayOfWeek,
      data.startTime,
      data.endTime,
      data.room ?? null,
      data.building ?? null,
      data.modality ?? null,
      data.weekPattern ?? 'every',
    );

  res.status(201).json({ data: toSlot(ownedSlot(info.lastInsertRowid, req.userId)) });
});

// PUT /api/schedule/:id
router.put('/:id', (req, res) => {
  const id = Number(req.params.id);
  const current = ownedSlot(id, req.userId);
  const data = validate(slotUpdateSchema, req.body);

  if (data.subjectId !== undefined) ownedSubject(data.subjectId, req.userId);

  db.prepare(
    'UPDATE schedule_slots SET subject_id = ?, day_of_week = ?, start_time = ?, end_time = ?, room = ?, building = ?, modality = ?, week_pattern = ? WHERE id = ?',
  ).run(
    data.subjectId ?? current.subject_id,
    data.dayOfWeek ?? current.day_of_week,
    data.startTime ?? current.start_time,
    data.endTime ?? current.end_time,
    data.room !== undefined ? data.room : current.room,
    data.building !== undefined ? data.building : current.building,
    data.modality !== undefined ? data.modality : current.modality,
    data.weekPattern ?? current.week_pattern,
    id,
  );

  res.json({ data: toSlot(ownedSlot(id, req.userId)) });
});

// DELETE /api/schedule/:id
router.delete('/:id', (req, res) => {
  const id = Number(req.params.id);
  ownedSlot(id, req.userId);
  const recycleBinId = recycleBin.trashRecord(req.userId, 'schedule', id);
  res.json({ data: { success: true, recycleBinId } });
});

module.exports = router;
