const { z } = require('zod');

const { validate } = require('../utils/validate');
const { asyncHandler } = require('../utils/async-handler');
const { HttpError } = require('../utils/errors');
const AttendanceModel = require('../models/attendance.model');
const { attendanceSummary } = require('../services/attendance');
const { toRecord } = require('../views/attendance.view');

const dateRegex = /^\d{4}-\d{2}-\d{2}$/;

const attendanceSchema = z.object({
  subjectId: z.number().int().positive(),
  slotId: z.number().int().positive().nullish(),
  date: z.string().regex(dateRegex, 'date must be YYYY-MM-DD'),
  status: z.enum(['present', 'absent', 'late', 'cancelled']),
  note: z.string().nullish(),
});

const attendanceUpdateSchema = attendanceSchema.partial();

async function ownedSubject(subjectId, userId) {
  if (!(await AttendanceModel.subjectExistsAndOwned(subjectId, userId))) {
    throw new HttpError(404, 'Subject not found');
  }
}

async function ownedRecord(id, userId) {
  const row = await AttendanceModel.findByIdAndUserId(Number(id), userId);
  if (!row) throw new HttpError(404, 'Attendance record not found');
  return row;
}

const AttendanceController = {
  getSummary: asyncHandler(async (req, res) => {
    res.json({ data: await attendanceSummary(req.userId) });
  }),

  getAll: asyncHandler(async (req, res) => {
    const { subjectId, from, to } = req.query;
    const rows = await AttendanceModel.findAllByUserId(req.userId, { subjectId, from, to });
    res.json({ data: rows.map(toRecord) });
  }),

  create: asyncHandler(async (req, res) => {
    const data = validate(attendanceSchema, req.body);
    await ownedSubject(data.subjectId, req.userId);

    const duplicate = await AttendanceModel.findDuplicate(
      data.subjectId,
      data.date,
      data.slotId ?? null,
    );
    if (duplicate) {
      throw new HttpError(409, 'Attendance for this session is already recorded');
    }

    const recordId = await AttendanceModel.create({
      subjectId: data.subjectId,
      slotId: data.slotId ?? null,
      date: data.date,
      status: data.status,
      note: data.note ?? null,
    });

    res.status(201).json({ data: toRecord(await ownedRecord(recordId, req.userId)) });
  }),

  update: asyncHandler(async (req, res) => {
    const id = Number(req.params.id);
    const current = await ownedRecord(id, req.userId);
    const data = validate(attendanceUpdateSchema, req.body);

    if (data.subjectId !== undefined) await ownedSubject(data.subjectId, req.userId);

    await AttendanceModel.update(id, data, current);
    res.json({ data: toRecord(await ownedRecord(id, req.userId)) });
  }),

  delete: asyncHandler(async (req, res) => {
    const id = Number(req.params.id);
    await ownedRecord(id, req.userId);
    await AttendanceModel.delete(id);
    res.status(204).end();
  }),
};

module.exports = AttendanceController;
