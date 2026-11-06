const { z } = require('zod');

const { validate } = require('../utils/validate');
const { parseId, parseOptionalInt, parsePagination } = require('../utils/parse');
const { HttpError } = require('../utils/errors');
const ScheduleModel = require('../models/schedule.model');
const { toSlot } = require('../views/schedule.view');

const timeRegex = /^([01]\d|2[0-3]):[0-5]\d$/;

const slotSchema = z.object({
  subjectId: z.number().int().positive(),
  dayOfWeek: z.number().int().min(0).max(6),
  startTime: z.string().regex(timeRegex, 'startTime must be HH:MM (24h)'),
  endTime: z.string().regex(timeRegex, 'endTime must be HH:MM (24h)'),
  room: z.string().trim().max(120).nullish(),
  modality: z.string().trim().max(60).nullish(),
});

const slotUpdateSchema = slotSchema.partial();

async function ownedSlot(id, userId) {
  const row = await ScheduleModel.findByIdAndUserId(parseId(id), userId);
  if (!row) throw new HttpError(404, 'Schedule slot not found');
  return row;
}

function assertTimeRange(startTime, endTime) {
  if (endTime <= startTime) {
    throw new HttpError(400, 'endTime must be later than startTime');
  }
}

async function ownedSubject(subjectId, userId) {
  if (!(await ScheduleModel.subjectExistsAndOwned(subjectId, userId))) {
    throw new HttpError(404, 'Subject not found');
  }
}

const ScheduleController = {
  getAll: async (req, res) => {
    const day = parseOptionalInt(req.query.day, { name: 'day', min: 0, max: 6 });
    const { limit, offset } = parsePagination(req.query);
    const rows = await ScheduleModel.findAllByUserId(req.userId, { day, limit, offset });
    res.json({ data: rows.map(toSlot) });
  },

  create: async (req, res) => {
    const data = validate(slotSchema, req.body);
    await ownedSubject(data.subjectId, req.userId);
    assertTimeRange(data.startTime, data.endTime);

    const slot = await ScheduleModel.create({
      subjectId: data.subjectId,
      dayOfWeek: data.dayOfWeek,
      startTime: data.startTime,
      endTime: data.endTime,
      room: data.room ?? null,
      modality: data.modality ?? null,
    });

    res.status(201).json({ data: toSlot(slot) });
  },

  update: async (req, res) => {
    const id = parseId(req.params.id);
    const current = await ownedSlot(id, req.userId);
    const data = validate(slotUpdateSchema, req.body);

    if (data.subjectId !== undefined) await ownedSubject(data.subjectId, req.userId);
    assertTimeRange(data.startTime ?? current.start_time, data.endTime ?? current.end_time);

    const updated = await ScheduleModel.update(id, data, current, req.userId);
    if (!updated) throw new HttpError(404, 'Schedule slot not found');
    res.json({ data: toSlot(updated) });
  },

  delete: async (req, res) => {
    const id = parseId(req.params.id);
    const result = await ScheduleModel.delete(id, req.userId);
    if (!result.rowCount) throw new HttpError(404, 'Schedule slot not found');
    res.status(204).end();
  },
};

module.exports = ScheduleController;
