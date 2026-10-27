const { z } = require('zod');

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
  note: z.string().nullish(),
});

const attendanceUpdateSchema = attendanceSchema.partial();

function ownedSubject(subjectId, userId) {
  if (!AttendanceModel.subjectExistsAndOwned(subjectId, userId)) {
    throw new HttpError(404, 'Subject not found');
  }
}

function ownedRecord(id, userId) {
  const row = AttendanceModel.findByIdAndUserId(Number(id), userId);
  if (!row) throw new HttpError(404, 'Attendance record not found');
  return row;
}

const AttendanceController = {
  getSummary: (req, res) => {
    res.json({ data: attendanceSummary(req.userId) });
  },

  getAll: (req, res) => {
    const { subjectId, from, to } = req.query;
    const rows = AttendanceModel.findAllByUserId(req.userId, { subjectId, from, to });
    res.json({ data: rows.map(toRecord) });
  },

  create: (req, res) => {
    const data = validate(attendanceSchema, req.body);
    ownedSubject(data.subjectId, req.userId);

    const duplicate = AttendanceModel.findDuplicate(data.subjectId, data.date, data.slotId ?? null);
    if (duplicate) {
      throw new HttpError(409, 'Attendance for this session is already recorded');
    }

    const recordId = AttendanceModel.create({
      subjectId: data.subjectId,
      slotId: data.slotId ?? null,
      date: data.date,
      status: data.status,
      note: data.note ?? null,
    });

    res.status(201).json({ data: toRecord(ownedRecord(recordId, req.userId)) });
  },

  update: (req, res) => {
    const id = Number(req.params.id);
    const current = ownedRecord(id, req.userId);
    const data = validate(attendanceUpdateSchema, req.body);

    if (data.subjectId !== undefined) ownedSubject(data.subjectId, req.userId);

    AttendanceModel.update(id, data, current);
    res.json({ data: toRecord(ownedRecord(id, req.userId)) });
  },

  delete: (req, res) => {
    const id = Number(req.params.id);
    ownedRecord(id, req.userId);
    AttendanceModel.delete(id);
    res.status(204).end();
  },
};

module.exports = AttendanceController;
