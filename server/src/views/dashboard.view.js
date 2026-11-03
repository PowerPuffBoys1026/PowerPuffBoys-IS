/**
 * View: shapes dashboard rows into the dashboard JSON payload.
 */

function toIsoString(value) {
  if (!value) return value;
  return value instanceof Date ? value.toISOString() : value;
}

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
  const dueAt = toIsoString(row.due_at);
  return {
    id: row.id,
    title: row.title,
    type: row.type,
    dueAt,
    priority: row.priority,
    status: row.status,
    subjectCode: row.subject_code,
    color: row.color,
    overdue: dueAt ? dueAt.slice(0, 10) < today : false,
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
