const { z } = require('zod');

const { validate } = require('../utils/validate');
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

function ownedWork(id, userId) {
  const row = WorkModel.findByIdAndUserId(Number(id), userId);
  if (!row) throw new HttpError(404, 'School work not found');
  return row;
}

function ownedSubjectIfAny(subjectId, userId) {
  if (subjectId === undefined || subjectId === null) return;
  if (!WorkModel.subjectExistsAndOwned(subjectId, userId)) {
    throw new HttpError(404, 'Subject not found');
  }
}

const WorkController = {
  getAll: (req, res) => {
    const { status, subjectId, dueBefore } = req.query;
    const rows = WorkModel.findAllByUserId(req.userId, { status, subjectId, dueBefore });
    res.json({ data: rows.map(toWork) });
  },

  create: (req, res) => {
    const data = validate(workSchema, req.body);
    ownedSubjectIfAny(data.subjectId ?? null, req.userId);

    const workId = WorkModel.create({
      userId: req.userId,
      subjectId: data.subjectId ?? null,
      title: data.title,
      type: data.type ?? 'assignment',
      dueAt: data.dueAt ?? null,
      priority: data.priority ?? 'medium',
      status: data.status ?? 'todo',
      notes: data.notes ?? null,
    });

    res.status(201).json({ data: toWork(ownedWork(workId, req.userId)) });
  },

  getOne: (req, res) => {
    res.json({ data: toWork(ownedWork(req.params.id, req.userId)) });
  },

  update: (req, res) => {
    const id = Number(req.params.id);
    const current = ownedWork(id, req.userId);
    const data = validate(workUpdateSchema, req.body);

    if (data.subjectId !== undefined) ownedSubjectIfAny(data.subjectId, req.userId);

    WorkModel.update(id, data, current);
    res.json({ data: toWork(ownedWork(id, req.userId)) });
  },

  updateStatus: (req, res) => {
    const id = Number(req.params.id);
    ownedWork(id, req.userId);
    const { status } = validate(statusSchema, req.body);
    WorkModel.updateStatus(id, status);
    res.json({ data: toWork(ownedWork(id, req.userId)) });
  },

  delete: (req, res) => {
    const id = Number(req.params.id);
    ownedWork(id, req.userId);
    WorkModel.delete(id);
    res.status(204).end();
  },
};

module.exports = WorkController;
