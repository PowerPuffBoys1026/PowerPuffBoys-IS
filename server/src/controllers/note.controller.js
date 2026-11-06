const { z } = require('zod');

const { validate } = require('../utils/validate');
const { parseId, parseOptionalBoolean, parseOptionalString } = require('../utils/parse');
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

async function ownedNote(id, userId) {
  const row = await NoteModel.findByIdAndUserId(parseId(id), userId);
  if (!row) throw new HttpError(404, 'Note not found');
  return row;
}

const NoteController = {
  getAll: async (req, res) => {
    const search = parseOptionalString(req.query.search, 'search');
    const tag = parseOptionalString(req.query.tag, 'tag');
    const pinned = parseOptionalBoolean(req.query.pinned, 'pinned');

    const rows = await NoteModel.findAllByUserId(req.userId, { search, tag, pinned });
    res.json({ data: rows.map(toNote) });
  },

  create: async (req, res) => {
    const data = validate(noteSchema, req.body);
    const noteId = await NoteModel.create({
      userId: req.userId,
      title: data.title ?? 'Untitled',
      content: data.content ?? '',
      isPinned: data.isPinned ?? false,
      color: data.color ?? '#1C223D',
      tags: data.tags ?? null,
    });
    res.status(201).json({ data: toNote(await ownedNote(noteId, req.userId)) });
  },

  getOne: async (req, res) => {
    res.json({ data: toNote(await ownedNote(req.params.id, req.userId)) });
  },

  update: async (req, res) => {
    const id = parseId(req.params.id);
    const current = await ownedNote(id, req.userId);
    const data = validate(noteUpdateSchema, req.body);
    await NoteModel.update(id, data, current);
    res.json({ data: toNote(await ownedNote(id, req.userId)) });
  },

  togglePin: async (req, res) => {
    const id = parseId(req.params.id);
    await ownedNote(id, req.userId);
    await NoteModel.togglePin(id);
    res.json({ data: toNote(await ownedNote(id, req.userId)) });
  },

  delete: async (req, res) => {
    const id = parseId(req.params.id);
    await ownedNote(id, req.userId);
    await NoteModel.delete(id);
    res.status(204).end();
  },
};

module.exports = NoteController;
