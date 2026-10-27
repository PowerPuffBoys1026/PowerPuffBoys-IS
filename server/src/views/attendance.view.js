/**
 * View: shapes an attendance row into the attendance JSON payload.
 */
function toRecord(row) {
  return {
    id: row.id,
    subjectId: row.subject_id,
    slotId: row.slot_id,
    date: row.date,
    status: row.status,
    note: row.note,
    createdAt: row.created_at,
  };
}

module.exports = { toRecord };
