const { z } = require('zod');

const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const SubjectModel = require('../models/subject.model');
const { toSubject } = require('../views/subject.view');

const subjectSchema = z.object({
  code: z.string().min(1, 'Subject code is required'),
  title: z.string().min(1, 'Subject title is required'),
  instructor: z.string().nullish(),
  units: z.number().int().min(0).max(20).optional(),
  color: z
    .string()
    .regex(/^#[0-9a-fA-F]{6}$/, 'color must be a hex value like #4F46E5')
    .optional(),
});

const subjectUpdateSchema = subjectSchema.partial();

function ownedSubject(id, userId) {
  const row = SubjectModel.findByIdAndUserId(Number(id), userId);
  if (!row) throw new HttpError(404, 'Subject not found');
  return row;
}

const SubjectController = {
  getAll: (req, res) => {
    const rows = SubjectModel.findAllByUserId(req.userId);
    res.json({ data: rows.map(toSubject) });
  },

  create: (req, res) => {
    const data = validate(subjectSchema, req.body);
    const subject = SubjectModel.create({
      userId: req.userId,
      code: data.code,
      title: data.title,
      instructor: data.instructor ?? null,
      units: data.units ?? 0,
      color: data.color ?? '#4F46E5',
    });
    res.status(201).json({ data: toSubject(subject) });
  },

  getOne: (req, res) => {
    const subject = ownedSubject(req.params.id, req.userId);
    res.json({ data: toSubject(subject) });
  },

  update: (req, res) => {
    const id = Number(req.params.id);
    const current = ownedSubject(id, req.userId);
    const data = validate(subjectUpdateSchema, req.body);

    const updated = SubjectModel.update(id, {
      code: data.code ?? current.code,
      title: data.title ?? current.title,
      instructor: data.instructor !== undefined ? data.instructor : current.instructor,
      units: data.units ?? current.units,
      color: data.color ?? current.color,
    });

    res.json({ data: toSubject(updated) });
  },

  delete: (req, res) => {
    const id = Number(req.params.id);
    ownedSubject(id, req.userId);
    SubjectModel.delete(id);
    res.status(204).end();
  },
};

module.exports = SubjectController;
