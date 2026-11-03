const { z } = require('zod');

const { validate } = require('../utils/validate');
const { asyncHandler } = require('../utils/async-handler');
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
  const row = await WorkModel.findByIdAndUserId(Number(id), userId);
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
  getAll: asyncHandler(async (req, res) => {
    const { status, subjectId, dueBefore } = req.query;
    const rows = await WorkModel.findAllByUserId(req.userId, { status, subjectId, dueBefore });
    res.json({ data: rows.map(toWork) });
  }),

  create: asyncHandler(async (req, res) => {
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
  }),

  getOne: asyncHandler(async (req, res) => {
    res.json({ data: toWork(await ownedWork(req.params.id, req.userId)) });
  }),

  update: asyncHandler(async (req, res) => {
    const id = Number(req.params.id);
    const current = await ownedWork(id, req.userId);
    const data = validate(workUpdateSchema, req.body);

    if (data.subjectId !== undefined) await ownedSubjectIfAny(data.subjectId, req.userId);

    await WorkModel.update(id, data, current);
    res.json({ data: toWork(await ownedWork(id, req.userId)) });
  }),

  updateStatus: asyncHandler(async (req, res) => {
    const id = Number(req.params.id);
    await ownedWork(id, req.userId);
    const { status } = validate(statusSchema, req.body);
    await WorkModel.updateStatus(id, status);
    res.json({ data: toWork(await ownedWork(id, req.userId)) });
  }),

  delete: asyncHandler(async (req, res) => {
    const id = Number(req.params.id);
    await ownedWork(id, req.userId);
    await WorkModel.delete(id);
    res.status(204).end();
  }),
};

module.exports = WorkController;
