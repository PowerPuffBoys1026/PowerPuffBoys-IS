const { z } = require('zod');

const { validate } = require('../utils/validate');
const {
  parseId,
  parseOptionalBoolean,
  parseOptionalString,
  parsePagination,
} = require('../utils/parse');
const { HttpError } = require('../utils/errors');
const NoteModel = require('../models/note.model');
const { toNote } = require('../views/note.view');

const noteSchema = z.object({
  title: z.string().trim().min(1).max(200).optional(),
  content: z.string().max(20000).optional(),
  isPinned: z.boolean().optional(),
  color: z
    .string()
    .regex(/^#[0-9a-fA-F]{6}$/, 'color must be a hex value like #1C223D')
    .optional(),
  tags: z.string().max(500).nullish(),
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
    const { limit, offset } = parsePagination(req.query);

    const rows = await NoteModel.findAllByUserId(req.userId, {
      search,
      tag,
      pinned,
      limit,
      offset,
    });
    res.json({ data: rows.map(toNote) });
  },

  create: async (req, res) => {
    const data = validate(noteSchema, req.body);
    const note = await NoteModel.create({
      userId: req.userId,
      title: data.title ?? 'Untitled',
      content: data.content ?? '',
      isPinned: data.isPinned ?? false,
      color: data.color ?? '#1C223D',
      tags: data.tags ?? null,
    });
    res.status(201).json({ data: toNote(note) });
  },

  getOne: async (req, res) => {
    res.json({ data: toNote(await ownedNote(req.params.id, req.userId)) });
  },

  update: async (req, res) => {
    const id = parseId(req.params.id);
    const current = await ownedNote(id, req.userId);
    const data = validate(noteUpdateSchema, req.body);
    const updated = await NoteModel.update(id, data, current, req.userId);
    if (!updated) throw new HttpError(404, 'Note not found');
    res.json({ data: toNote(updated) });
  },

  togglePin: async (req, res) => {
    const id = parseId(req.params.id);
    const updated = await NoteModel.togglePin(id, req.userId);
    if (!updated) throw new HttpError(404, 'Note not found');
    res.json({ data: toNote(updated) });
  },

  delete: async (req, res) => {
    const id = parseId(req.params.id);
    const result = await NoteModel.delete(id, req.userId);
    if (!result.rowCount) throw new HttpError(404, 'Note not found');
    res.status(204).end();
  },
};

module.exports = NoteController;
