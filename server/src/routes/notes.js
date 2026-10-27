const express = require('express');
const { z } = require('zod');

const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const recycleBin = require('../services/recycle_bin');

const router = express.Router();
router.use(requireAuth);

const noteSchema = z.object({
  subjectId: z.number().int().nullish(),
  title: z.string().min(1, 'Title is required'),
  content: z.string().min(1, 'Content is required'),
  tags: z.string().nullish(),
  isPinned: z.boolean().default(false),
});

const noteUpdateSchema = noteSchema.partial();

function toNote(row) {
  return {
    id: row.id,
    subjectId: row.subject_id,
    subjectCode: row.subject_code,
    subjectTitle: row.subject_title,
    subjectColor: row.subject_color,
    title: row.title,
    content: row.content,
    tags: row.tags,
    isPinned: Boolean(row.is_pinned),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// GET /api/notes
router.get('/', (req, res) => {
  const subjectId = req.query.subjectId ? Number(req.query.subjectId) : null;

  let query = `
    SELECT n.id, n.subject_id, n.title, n.content, n.tags, n.is_pinned, n.created_at, n.updated_at,
           s.code AS subject_code, s.title AS subject_title, s.color AS subject_color
      FROM subject_notes n
 LEFT JOIN subjects s ON s.id = n.subject_id
     WHERE n.user_id = ?
  `;
  const params = [req.userId];

  if (subjectId) {
    query += ' AND n.subject_id = ?';
    params.push(subjectId);
  }

  query += ' ORDER BY n.is_pinned DESC, n.updated_at DESC';

  const rows = db.prepare(query).all(...params);
  res.json({ data: rows.map(toNote) });
});

// POST /api/notes
router.post('/', (req, res) => {
  const data = validate(noteSchema, req.body);

  if (data.subjectId) {
    const subject = db
      .prepare('SELECT id FROM subjects WHERE id = ? AND user_id = ?')
      .get(data.subjectId, req.userId);
    if (!subject) throw new HttpError(404, 'Subject not found');
  }

  const info = db
    .prepare(
      `INSERT INTO subject_notes (user_id, subject_id, title, content, tags, is_pinned)
       VALUES (?, ?, ?, ?, ?, ?)`,
    )
    .run(
      req.userId,
      data.subjectId ?? null,
      data.title,
      data.content,
      data.tags ?? null,
      data.isPinned ? 1 : 0,
    );

  const row = db
    .prepare(
      `SELECT n.id, n.subject_id, n.title, n.content, n.tags, n.is_pinned, n.created_at, n.updated_at,
              s.code AS subject_code, s.title AS subject_title, s.color AS subject_color
         FROM subject_notes n
    LEFT JOIN subjects s ON s.id = n.subject_id
        WHERE n.id = ?`,
    )
    .get(info.lastInsertRowid);

  res.status(201).json({ data: toNote(row) });
});

// PUT /api/notes/:id
router.put('/:id', (req, res) => {
  const current = db
    .prepare('SELECT id, subject_id, title, content, tags, is_pinned FROM subject_notes WHERE id = ? AND user_id = ?')
    .get(req.params.id, req.userId);
  if (!current) throw new HttpError(404, 'Note not found');

  const data = validate(noteUpdateSchema, req.body);
  if (data.subjectId !== undefined && data.subjectId !== null) {
    const subject = db
      .prepare('SELECT id FROM subjects WHERE id = ? AND user_id = ?')
      .get(data.subjectId, req.userId);
    if (!subject) throw new HttpError(404, 'Subject not found');
  }

  db.prepare(
    `UPDATE subject_notes
        SET subject_id = ?, title = ?, content = ?, tags = ?, is_pinned = ?, updated_at = datetime('now')
      WHERE id = ?`,
  ).run(
    data.subjectId !== undefined ? data.subjectId : current.subject_id,
    data.title ?? current.title,
    data.content ?? current.content,
    data.tags !== undefined ? data.tags : current.tags,
    data.isPinned !== undefined ? (data.isPinned ? 1 : 0) : current.is_pinned,
    req.params.id,
  );

  const updated = db
    .prepare(
      `SELECT n.id, n.subject_id, n.title, n.content, n.tags, n.is_pinned, n.created_at, n.updated_at,
              s.code AS subject_code, s.title AS subject_title, s.color AS subject_color
         FROM subject_notes n
    LEFT JOIN subjects s ON s.id = n.subject_id
        WHERE n.id = ?`,
    )
    .get(req.params.id);

  res.json({ data: toNote(updated) });
});

// DELETE /api/notes/:id
router.delete('/:id', (req, res) => {
  const current = db
    .prepare('SELECT id FROM subject_notes WHERE id = ? AND user_id = ?')
    .get(req.params.id, req.userId);
  if (!current) throw new HttpError(404, 'Note not found');

  const recycleBinId = recycleBin.trashRecord(req.userId, 'note', Number(req.params.id));
  res.json({ data: { success: true, recycleBinId } });
});

module.exports = router;
