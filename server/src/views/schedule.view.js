/**
 * View: shapes a schedule slot row into the slot JSON payload.
 */
function formatTime(value) {
  return typeof value === 'string' ? value.slice(0, 5) : value;
}

function toSlot(row) {
  return {
    id: row.id,
    subjectId: row.subject_id,
    subjectCode: row.subject_code,
    subjectTitle: row.subject_title,
    color: row.color,
    dayOfWeek: row.day_of_week,
    startTime: formatTime(row.start_time),
    endTime: formatTime(row.end_time),
    room: row.room,
    building: row.building ?? null,
    modality: row.modality,
    weekPattern: row.week_pattern ?? 'every',
  };
}

module.exports = { toSlot };
