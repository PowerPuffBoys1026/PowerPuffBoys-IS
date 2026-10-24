const express = require('express');
const { z } = require('zod');

const db = require('../db');
const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const recycleBin = require('../services/recycle_bin');
const { requireAuth } = require('../middleware/auth');
const { attendanceSummary } = require('../services/attendance');

const router = express.Router();
router.use(requireAuth);

const dateRegex = /^\d{4}-\d{2}-\d{2}$/;

const attendanceSchema = z.object({
  subjectId: z.number().int().positive(),
  slotId: z.number().int().positive().nullish(),
  date: z.string().regex(dateRegex, 'date must be YYYY-MM-DD'),
  status: z.enum(['present', 'absent', 'late', 'cancelled']),
  note: z.string().nullish(),
});

const attendanceUpdateSchema = attendanceSchema.partial();

function toRecord(row) {
  return {
    id: row.id,
    subjectId: row.subject_id,
    slotId: row.slot_id,
    date: row.date,
    status: row.status,
    note: row.note,
    createdAt: row.created_at,
  };
}

function ownedSubject(subjectId, userId) {
  const row = db.prepare('SELECT id FROM subjects WHERE id = ? AND user_id = ?').get(subjectId, userId);
  if (!row) throw new HttpError(404, 'Subject not found');
  return row;
}

function ownedRecord(id, userId) {
  const row = db
    .prepare(
      `SELECT a.* FROM attendance_records a
        JOIN subjects s ON s.id = a.subject_id
       WHERE a.id = ? AND s.user_id = ?`,
    )
    .get(id, userId);
  if (!row) throw new HttpError(404, 'Attendance record not found');
  return row;
}

// GET /api/attendance/summary  (declared before /:id)
router.get('/summary', (req, res) => {
  res.json({ data: attendanceSummary(req.userId) });
});

// GET /api/attendance?subjectId=&from=&to=
router.get('/', (req, res) => {
  const { subjectId, from, to } = req.query;
  const params = [req.userId];
  let sql = `SELECT a.* FROM attendance_records a
               JOIN subjects s ON s.id = a.subject_id
              WHERE s.user_id = ?`;

  if (subjectId) {
    sql += ' AND a.subject_id = ?';
    params.push(Number(subjectId));
  }
  if (from) {
    sql += ' AND a.date >= ?';
    params.push(from);
  }
  if (to) {
    sql += ' AND a.date <= ?';
    params.push(to);
  }

  sql += ' ORDER BY a.date DESC';
  res.json({ data: db.prepare(sql).all(...params).map(toRecord) });
});

// POST /api/attendance
router.post('/', (req, res) => {
  const data = validate(attendanceSchema, req.body);
  ownedSubject(data.subjectId, req.userId);

  const slotId = data.slotId ?? null;
  const duplicate = db
    .prepare(
      `SELECT id FROM attendance_records
        WHERE subject_id = ? AND date = ? AND ${slotId === null ? 'slot_id IS NULL' : 'slot_id = ?'}`,
    )
    .get(...(slotId === null ? [data.subjectId, data.date] : [data.subjectId, data.date, slotId]));

  if (duplicate) {
    throw new HttpError(409, 'Attendance for this session is already recorded');
  }

  const info = db
    .prepare('INSERT INTO attendance_records (subject_id, slot_id, date, status, note) VALUES (?, ?, ?, ?, ?)')
    .run(data.subjectId, slotId, data.date, data.status, data.note ?? null);

  res.status(201).json({ data: toRecord(ownedRecord(info.lastInsertRowid, req.userId)) });
});

// PUT /api/attendance/:id
router.put('/:id', (req, res) => {
  const id = Number(req.params.id);
  const current = ownedRecord(id, req.userId);
  const data = validate(attendanceUpdateSchema, req.body);

  if (data.subjectId !== undefined) ownedSubject(data.subjectId, req.userId);

  db.prepare(
    'UPDATE attendance_records SET subject_id = ?, slot_id = ?, date = ?, status = ?, note = ? WHERE id = ?',
  ).run(
    data.subjectId ?? current.subject_id,
    data.slotId !== undefined ? data.slotId : current.slot_id,
    data.date ?? current.date,
    data.status ?? current.status,
    data.note !== undefined ? data.note : current.note,
    id,
  );

  res.json({ data: toRecord(ownedRecord(id, req.userId)) });
});

// DELETE /api/attendance/:id
router.delete('/:id', (req, res) => {
  const id = Number(req.params.id);
  ownedRecord(id, req.userId);
  const recycleBinId = recycleBin.trashRecord(req.userId, 'attendance', id);
  res.json({ data: { success: true, recycleBinId } });
});

module.exports = router;
