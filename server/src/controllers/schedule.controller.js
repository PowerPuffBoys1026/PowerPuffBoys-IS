const { z } = require('zod');

const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const ScheduleModel = require('../models/schedule.model');
const { toSlot } = require('../views/schedule.view');

const timeRegex = /^([01]\d|2[0-3]):[0-5]\d$/;

const slotSchema = z.object({
  subjectId: z.number().int().positive(),
  dayOfWeek: z.number().int().min(0).max(6),
  startTime: z.string().regex(timeRegex, 'startTime must be HH:MM (24h)'),
  endTime: z.string().regex(timeRegex, 'endTime must be HH:MM (24h)'),
  room: z.string().nullish(),
  modality: z.string().nullish(),
});

const slotUpdateSchema = slotSchema.partial();

function ownedSlot(id, userId) {
  const row = ScheduleModel.findByIdAndUserId(Number(id), userId);
  if (!row) throw new HttpError(404, 'Schedule slot not found');
  return row;
}

function ownedSubject(subjectId, userId) {
  if (!ScheduleModel.subjectExistsAndOwned(subjectId, userId)) {
    throw new HttpError(404, 'Subject not found');
  }
}

const ScheduleController = {
  getAll: (req, res) => {
    const { day } = req.query;
    if (day !== undefined && day !== '') {
      const dayNum = Number(day);
      if (!Number.isInteger(dayNum) || dayNum < 0 || dayNum > 6) {
        throw new HttpError(400, 'day must be an integer between 0 and 6');
      }
    }
    const rows = ScheduleModel.findAllByUserId(req.userId, day);
    res.json({ data: rows.map(toSlot) });
  },

  create: (req, res) => {
    const data = validate(slotSchema, req.body);
    ownedSubject(data.subjectId, req.userId);

    const slotId = ScheduleModel.create({
      subjectId: data.subjectId,
      dayOfWeek: data.dayOfWeek,
      startTime: data.startTime,
      endTime: data.endTime,
      room: data.room ?? null,
      modality: data.modality ?? null,
    });

    res.status(201).json({ data: toSlot(ownedSlot(slotId, req.userId)) });
  },

  update: (req, res) => {
    const id = Number(req.params.id);
    const current = ownedSlot(id, req.userId);
    const data = validate(slotUpdateSchema, req.body);

    if (data.subjectId !== undefined) ownedSubject(data.subjectId, req.userId);

    ScheduleModel.update(id, data, current);
    res.json({ data: toSlot(ownedSlot(id, req.userId)) });
  },

  delete: (req, res) => {
    const id = Number(req.params.id);
    ownedSlot(id, req.userId);
    ScheduleModel.delete(id);
    res.status(204).end();
  },
};

module.exports = ScheduleController;
