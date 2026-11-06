const { z } = require('zod');

const {
  parseId,
  parseOptionalInt,
  parseOptionalDate,
  parsePagination,
} = require('../utils/parse');
const { validate } = require('../utils/validate');
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
  note: z.string().max(500).nullish(),
});

const attendanceUpdateSchema = attendanceSchema.partial();

async function ownedSubject(subjectId, userId) {
  if (!(await AttendanceModel.subjectExistsAndOwned(subjectId, userId))) {
    throw new HttpError(404, 'Subject not found');
  }
}

async function ownedRecord(id, userId) {
  const row = await AttendanceModel.findByIdAndUserId(id, userId);
  if (!row) throw new HttpError(404, 'Attendance record not found');
  return row;
}

async function ownedSlot(slotId, subjectId, userId) {
  if (slotId === null || slotId === undefined) return;
  if (!(await AttendanceModel.slotExistsForSubjectAndUser(slotId, subjectId, userId))) {
    throw new HttpError(404, 'Schedule slot not found for this subject');
  }
}

const AttendanceController = {
  getSummary: async (req, res) => {
    res.json({ data: await attendanceSummary(req.userId) });
  },

  getAll: async (req, res) => {
    const subjectId = parseOptionalInt(req.query.subjectId, {
      name: 'subjectId',
      min: 1,
      max: Number.MAX_SAFE_INTEGER,
    });
    const from = parseOptionalDate(req.query.from, 'from');
    const to = parseOptionalDate(req.query.to, 'to');
    const { limit, offset } = parsePagination(req.query);

    const rows = await AttendanceModel.findAllByUserId(req.userId, {
      subjectId,
      from,
      to,
      limit,
      offset,
    });
    res.json({ data: rows.map(toRecord) });
  },

  create: async (req, res) => {
    const data = validate(attendanceSchema, req.body);
    await ownedSubject(data.subjectId, req.userId);
    await ownedSlot(data.slotId ?? null, data.subjectId, req.userId);

    const duplicate = await AttendanceModel.findDuplicate(data.subjectId, data.date, data.slotId ?? null);
    if (duplicate) {
      throw new HttpError(409, 'Attendance for this session is already recorded');
    }

    const record = await AttendanceModel.create({
      subjectId: data.subjectId,
      slotId: data.slotId ?? null,
      date: data.date,
      status: data.status,
      note: data.note ?? null,
    });

    res.status(201).json({ data: toRecord(record) });
  },

  update: async (req, res) => {
    const id = parseId(req.params.id);
    const current = await ownedRecord(id, req.userId);
    const data = validate(attendanceUpdateSchema, req.body);

    const subjectId = data.subjectId ?? current.subject_id;
    const slotId = data.slotId !== undefined ? data.slotId : current.slot_id;
    const date = data.date ?? current.date;

    if (data.subjectId !== undefined) await ownedSubject(subjectId, req.userId);
    await ownedSlot(slotId, subjectId, req.userId);

    const duplicate = await AttendanceModel.findDuplicate(subjectId, date, slotId ?? null, id);
    if (duplicate) {
      throw new HttpError(409, 'Attendance for this session is already recorded');
    }

    const updated = await AttendanceModel.update(id, data, current, req.userId);
    if (!updated) throw new HttpError(404, 'Attendance record not found');
    res.json({ data: toRecord(updated) });
  },

  delete: async (req, res) => {
    const id = parseId(req.params.id);
    const result = await AttendanceModel.delete(id, req.userId);
    if (!result.rowCount) throw new HttpError(404, 'Attendance record not found');
    res.status(204).end();
  },
};

module.exports = AttendanceController;
