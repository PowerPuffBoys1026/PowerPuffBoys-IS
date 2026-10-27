const express = require('express');
const { z } = require('zod');

const db = require('../db');
const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const recycleBin = require('../services/recycle_bin');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

const subjectSchema = z.object({
  code: z.string().min(1, 'Subject code is required'),
  title: z.string().min(1, 'Subject title is required'),
  instructor: z.string().nullish(),
  instructorEmail: z.string().email().nullish(),
  officeHours: z.string().nullish(),
  units: z.number().int().min(0).max(20).optional(),
  color: z
    .string()
    .regex(/^#[0-9a-fA-F]{6}$/, 'color must be a hex value like #4F46E5')
    .optional(),
});

const subjectUpdateSchema = subjectSchema.partial();

function toSubject(row) {
  return {
    id: row.id,
    code: row.code,
    title: row.title,
    instructor: row.instructor,
    instructorEmail: row.instructor_email,
    officeHours: row.office_hours,
    units: row.units,
    color: row.color,
    createdAt: row.created_at,
  };
}

function ownedSubject(id, userId) {
  const row = db.prepare('SELECT * FROM subjects WHERE id = ? AND user_id = ?').get(id, userId);
  if (!row) throw new HttpError(404, 'Subject not found');
  return row;
}

// GET /api/subjects
router.get('/', (req, res) => {
  const rows = db
    .prepare('SELECT * FROM subjects WHERE user_id = ? ORDER BY code')
    .all(req.userId);
  res.json({ data: rows.map(toSubject) });
});

// POST /api/subjects
router.post('/', (req, res) => {
  const data = validate(subjectSchema, req.body);
  const info = db
    .prepare(
      'INSERT INTO subjects (user_id, code, title, instructor, instructor_email, office_hours, units, color) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    )
    .run(
      req.userId,
      data.code,
      data.title,
      data.instructor ?? null,
      data.instructorEmail ?? null,
      data.officeHours ?? null,
      data.units ?? 0,
      data.color ?? '#4F46E5',
    );

  res.status(201).json({ data: toSubject(ownedSubject(info.lastInsertRowid, req.userId)) });
});

// GET /api/subjects/:id
router.get('/:id', (req, res) => {
  res.json({ data: toSubject(ownedSubject(Number(req.params.id), req.userId)) });
});

// PUT /api/subjects/:id
router.put('/:id', (req, res) => {
  const id = Number(req.params.id);
  const current = ownedSubject(id, req.userId);
  const data = validate(subjectUpdateSchema, req.body);

  db.prepare('UPDATE subjects SET code = ?, title = ?, instructor = ?, instructor_email = ?, office_hours = ?, units = ?, color = ? WHERE id = ?').run(
    data.code ?? current.code,
    data.title ?? current.title,
    data.instructor !== undefined ? data.instructor : current.instructor,
    data.instructorEmail !== undefined ? data.instructorEmail : current.instructor_email,
    data.officeHours !== undefined ? data.officeHours : current.office_hours,
    data.units ?? current.units,
    data.color ?? current.color,
    id,
  );

  res.json({ data: toSubject(ownedSubject(id, req.userId)) });
});

// DELETE /api/subjects/:id
router.delete('/:id', (req, res) => {
  const id = Number(req.params.id);
  const recycleBinId = recycleBin.trashRecord(req.userId, 'subject', id);
  res.json({ data: { success: true, recycleBinId } });
});

module.exports = router;
