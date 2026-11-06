const { z } = require('zod');

const { validate } = require('../utils/validate');
const {
  parseId,
  parseOptionalInt,
  parseOptionalDate,
  parseOptionalEnum,
} = require('../utils/parse');
const { HttpError } = require('../utils/errors');
const WorkModel = require('../models/work.model');
const { toWork } = require('../views/work.view');

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

async function ownedWork(id, userId) {
  const row = await WorkModel.findByIdAndUserId(parseId(id), userId);
  if (!row) throw new HttpError(404, 'School work not found');
  return row;
}

async function ownedSubjectIfAny(subjectId, userId) {
  if (subjectId === undefined || subjectId === null) return;
  if (!(await WorkModel.subjectExistsAndOwned(subjectId, userId))) {
    throw new HttpError(404, 'Subject not found');
  }
}

const WorkController = {
  getAll: async (req, res) => {
    const status = parseOptionalEnum(req.query.status, 'status', ['todo', 'doing', 'done']);
    const subjectId = parseOptionalInt(req.query.subjectId, {
      name: 'subjectId',
      min: 1,
      max: Number.MAX_SAFE_INTEGER,
    });
    const dueBefore = parseOptionalDate(req.query.dueBefore, 'dueBefore');

    const rows = await WorkModel.findAllByUserId(req.userId, { status, subjectId, dueBefore });
    res.json({ data: rows.map(toWork) });
  },

  create: async (req, res) => {
    const data = validate(workSchema, req.body);
    await ownedSubjectIfAny(data.subjectId ?? null, req.userId);

    const workId = await WorkModel.create({
      userId: req.userId,
      subjectId: data.subjectId ?? null,
      title: data.title,
      type: data.type ?? 'assignment',
      dueAt: data.dueAt ?? null,
      priority: data.priority ?? 'medium',
      status: data.status ?? 'todo',
      notes: data.notes ?? null,
    });

    res.status(201).json({ data: toWork(await ownedWork(workId, req.userId)) });
  },

  getOne: async (req, res) => {
    res.json({ data: toWork(await ownedWork(req.params.id, req.userId)) });
  },

  update: async (req, res) => {
    const id = parseId(req.params.id);
    const current = await ownedWork(id, req.userId);
    const data = validate(workUpdateSchema, req.body);

    if (data.subjectId !== undefined) await ownedSubjectIfAny(data.subjectId, req.userId);

    await WorkModel.update(id, data, current);
    res.json({ data: toWork(await ownedWork(id, req.userId)) });
  },

  updateStatus: async (req, res) => {
    const id = parseId(req.params.id);
    await ownedWork(id, req.userId);
    const { status } = validate(statusSchema, req.body);
    await WorkModel.updateStatus(id, status);
    res.json({ data: toWork(await ownedWork(id, req.userId)) });
  },

  delete: async (req, res) => {
    const id = parseId(req.params.id);
    await ownedWork(id, req.userId);
    await WorkModel.delete(id);
    res.status(204).end();
  },
};

module.exports = WorkController;
