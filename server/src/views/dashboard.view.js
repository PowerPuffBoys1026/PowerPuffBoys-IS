/**
 * View: shapes dashboard rows into the dashboard JSON payload.
 */

const { dateInTimeZone } = require('../utils/dates');

function toClass(row) {
  return {
    slotId: row.id,
    subjectId: row.subject_id,
    code: row.code,
    title: row.title,
    color: row.color,
    startTime: row.start_time,
    endTime: row.end_time,
    room: row.room,
    modality: row.modality,
  };
}

function toDueSoon(row, today) {
  const dueAt = row.due_at instanceof Date ? row.due_at.toISOString() : row.due_at;
  const dueDate = dueAt ? dateInTimeZone(new Date(dueAt)) : null;

  return {
    id: row.id,
    title: row.title,
    type: row.type,
    dueAt,
    priority: row.priority,
    status: row.status,
    subjectCode: row.subject_code,
    color: row.color,
    overdue: dueDate !== null && dueDate < today,
  };
}

function toDashboard({ date, dayName, classes, dueSoon, attendanceWarnings }) {
  return {
    date,
    dayName,
    classes: classes.map(toClass),
    dueSoon: dueSoon.map((row) => toDueSoon(row, date)),
    attendanceWarnings,
  };
}

module.exports = { toClass, toDueSoon, toDashboard };
