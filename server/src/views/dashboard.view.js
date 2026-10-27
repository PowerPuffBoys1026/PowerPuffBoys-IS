/**
 * View: shapes dashboard rows into the dashboard JSON payload.
 */

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
  return {
    id: row.id,
    title: row.title,
    type: row.type,
    dueAt: row.due_at,
    priority: row.priority,
    status: row.status,
    subjectCode: row.subject_code,
    color: row.color,
    overdue: row.due_at.slice(0, 10) < today,
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
