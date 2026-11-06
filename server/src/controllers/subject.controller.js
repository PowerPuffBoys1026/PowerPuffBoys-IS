const { z } = require('zod');

const { validate } = require('../utils/validate');
const { parseId, parsePagination } = require('../utils/parse');
const { HttpError } = require('../utils/errors');
const SubjectModel = require('../models/subject.model');
const { toSubject } = require('../views/subject.view');

const subjectSchema = z.object({
  code: z.string().trim().min(1, 'Subject code is required').max(20),
  title: z.string().trim().min(1, 'Subject title is required').max(200),
  instructor: z.string().trim().max(120).nullish(),
  units: z.number().int().min(0).max(20).optional(),
  color: z
    .string()
    .regex(/^#[0-9a-fA-F]{6}$/, 'color must be a hex value like #4F46E5')
    .optional(),
});

const subjectUpdateSchema = subjectSchema.partial();

async function ownedSubject(id, userId) {
  const row = await SubjectModel.findByIdAndUserId(parseId(id), userId);
  if (!row) throw new HttpError(404, 'Subject not found');
  return row;
}

const SubjectController = {
  getAll: async (req, res) => {
    const { limit, offset } = parsePagination(req.query);
    const rows = await SubjectModel.findAllByUserId(req.userId, { limit, offset });
    res.json({ data: rows.map(toSubject) });
  },

  create: async (req, res) => {
    const data = validate(subjectSchema, req.body);
    const subject = await SubjectModel.create({
      userId: req.userId,
      code: data.code,
      title: data.title,
      instructor: data.instructor ?? null,
      units: data.units ?? 0,
      color: data.color ?? '#4F46E5',
    });
    res.status(201).json({ data: toSubject(subject) });
  },

  getOne: async (req, res) => {
    const subject = await ownedSubject(req.params.id, req.userId);
    res.json({ data: toSubject(subject) });
  },

  update: async (req, res) => {
    const id = parseId(req.params.id);
    const current = await ownedSubject(id, req.userId);
    const data = validate(subjectUpdateSchema, req.body);

    const updated = await SubjectModel.update(id, {
      code: data.code ?? current.code,
      title: data.title ?? current.title,
      instructor: data.instructor !== undefined ? data.instructor : current.instructor,
      units: data.units ?? current.units,
      color: data.color ?? current.color,
    }, req.userId);

    if (!updated) throw new HttpError(404, 'Subject not found');
    res.json({ data: toSubject(updated) });
  },

  delete: async (req, res) => {
    const id = parseId(req.params.id);
    const result = await SubjectModel.delete(id, req.userId);
    if (!result.rowCount) throw new HttpError(404, 'Subject not found');
    res.status(204).end();
  },
};

module.exports = SubjectController;
