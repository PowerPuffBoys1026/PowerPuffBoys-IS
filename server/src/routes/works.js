const express = require('express');
const { z } = require('zod');

const db = require('../db');
const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const recycleBin = require('../services/recycle_bin');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

const workSchema = z.object({
  title: z.string().min(1, 'Title is required'),
  subjectId: z.number().int().positive().nullish(),
  type: z.enum(['assignment', 'quiz', 'exam', 'project']).optional(),
  dueAt: z
    .string()
    .refine((v) => !Number.isNaN(Date.parse(v)), 'dueAt must be a valid date/time')
    .nullish(),
  priority: z.enum(['low', 'medium', 'high']).optional(),
  status: z.enum(['todo', 'doing', 'done']).optional(),
  notes: z.string().nullish(),
});

const workUpdateSchema = workSchema.partial();

const statusSchema = z.object({ status: z.enum(['todo', 'doing', 'done']) });

function toWork(row) {
  return {
    id: row.id,
    title: row.title,
    subjectId: row.subject_id,
    subjectCode: row.subject_code ?? null,
    subjectTitle: row.subject_title ?? null,
    color: row.color ?? null,
    type: row.type,
    dueAt: row.due_at,
    priority: row.priority,
    status: row.status,
    notes: row.notes,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

const SELECT_WORK = `
  SELECT w.*, s.code AS subject_code, s.title AS subject_title, s.color
    FROM school_works w
    LEFT JOIN subjects s ON s.id = w.subject_id`;

function ownedWork(id, userId) {
  const row = db.prepare(`${SELECT_WORK} WHERE w.id = ? AND w.user_id = ?`).get(id, userId);
  if (!row) throw new HttpError(404, 'School work not found');
  return row;
}

function ownedSubjectIfAny(subjectId, userId) {
  if (subjectId === undefined || subjectId === null) return;
  const row = db.prepare('SELECT id FROM subjects WHERE id = ? AND user_id = ?').get(subjectId, userId);
  if (!row) throw new HttpError(404, 'Subject not found');
}

// GET /api/works?status=&subjectId=&dueBefore=
router.get('/', (req, res) => {
  const { status, subjectId, dueBefore } = req.query;
  const params = [req.userId];
  let sql = `${SELECT_WORK} WHERE w.user_id = ?`;

  if (status) {
    sql += ' AND w.status = ?';
    params.push(status);
  }
  if (subjectId) {
    sql += ' AND w.subject_id = ?';
    params.push(Number(subjectId));
  }
  if (dueBefore) {
    sql += " AND w.due_at IS NOT NULL AND date(w.due_at) <= date(?)";
    params.push(dueBefore);
  }

  // Unfinished first, then soonest due date.
  sql += " ORDER BY w.status = 'done', COALESCE(w.due_at, '9999-12-31')";
  res.json({ data: db.prepare(sql).all(...params).map(toWork) });
});

// POST /api/works
router.post('/', (req, res) => {
  const data = validate(workSchema, req.body);
  ownedSubjectIfAny(data.subjectId ?? null, req.userId);

  const info = db
    .prepare(
      'INSERT INTO school_works (user_id, subject_id, title, type, due_at, priority, status, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    )
    .run(
      req.userId,
      data.subjectId ?? null,
      data.title,
      data.type ?? 'assignment',
      data.dueAt ?? null,
      data.priority ?? 'medium',
      data.status ?? 'todo',
      data.notes ?? null,
    );

  res.status(201).json({ data: toWork(ownedWork(info.lastInsertRowid, req.userId)) });
});

// GET /api/works/:id
router.get('/:id', (req, res) => {
  res.json({ data: toWork(ownedWork(Number(req.params.id), req.userId)) });
});

// PUT /api/works/:id
router.put('/:id', (req, res) => {
  const id = Number(req.params.id);
  const current = ownedWork(id, req.userId);
  const data = validate(workUpdateSchema, req.body);

  if (data.subjectId !== undefined) ownedSubjectIfAny(data.subjectId, req.userId);

  db.prepare(
    `UPDATE school_works
        SET subject_id = ?, title = ?, type = ?, due_at = ?, priority = ?, status = ?, notes = ?,
            updated_at = datetime('now')
      WHERE id = ?`,
  ).run(
    data.subjectId !== undefined ? data.subjectId : current.subject_id,
    data.title ?? current.title,
    data.type ?? current.type,
    data.dueAt !== undefined ? data.dueAt : current.due_at,
    data.priority ?? current.priority,
    data.status ?? current.status,
    data.notes !== undefined ? data.notes : current.notes,
    id,
  );

  res.json({ data: toWork(ownedWork(id, req.userId)) });
});

// PATCH /api/works/:id/status
router.patch('/:id/status', (req, res) => {
  const id = Number(req.params.id);
  ownedWork(id, req.userId);
  const { status } = validate(statusSchema, req.body);

  db.prepare("UPDATE school_works SET status = ?, updated_at = datetime('now') WHERE id = ?").run(status, id);
  res.json({ data: toWork(ownedWork(id, req.userId)) });
});

// DELETE /api/works/:id
router.delete('/:id', (req, res) => {
  const id = Number(req.params.id);
  ownedWork(id, req.userId);
  const recycleBinId = recycleBin.trashRecord(req.userId, 'task', id);
  res.json({ data: { success: true, recycleBinId } });
});

module.exports = router;
