const { z } = require('zod');

const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const NoteModel = require('../models/note.model');
const { toNote } = require('../views/note.view');

const noteSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  content: z.string().optional(),
  isPinned: z.boolean().optional(),
  color: z.string().optional(),
  tags: z.string().nullish(),
});

const noteUpdateSchema = noteSchema.partial();

function ownedNote(id, userId) {
  const row = NoteModel.findByIdAndUserId(Number(id), userId);
  if (!row) throw new HttpError(404, 'Note not found');
  return row;
}

const NoteController = {
  getAll: (req, res) => {
    const { search, tag, pinned } = req.query;
    const rows = NoteModel.findAllByUserId(req.userId, { search, tag, pinned });
    res.json({ data: rows.map(toNote) });
  },

  create: (req, res) => {
    const data = validate(noteSchema, req.body);
    const noteId = NoteModel.create({
      userId: req.userId,
      title: data.title ?? 'Untitled',
      content: data.content ?? '',
      isPinned: data.isPinned ?? false,
      color: data.color ?? '#1C223D',
      tags: data.tags ?? null,
    });
    res.status(201).json({ data: toNote(ownedNote(noteId, req.userId)) });
  },

  getOne: (req, res) => {
    res.json({ data: toNote(ownedNote(req.params.id, req.userId)) });
  },

  update: (req, res) => {
    const id = Number(req.params.id);
    const current = ownedNote(id, req.userId);
    const data = validate(noteUpdateSchema, req.body);
    NoteModel.update(id, data, current);
    res.json({ data: toNote(ownedNote(id, req.userId)) });
  },

  togglePin: (req, res) => {
    const id = Number(req.params.id);
    ownedNote(id, req.userId);
    NoteModel.togglePin(id);
    res.json({ data: toNote(ownedNote(id, req.userId)) });
  },

  delete: (req, res) => {
    const id = Number(req.params.id);
    ownedNote(id, req.userId);
    NoteModel.delete(id);
    res.status(204).end();
  },
};

module.exports = NoteController;
