/**
 * View: shapes a subject row into the subject JSON payload.
 */
function toSubject(row) {
  return {
    id: row.id,
    code: row.code,
    title: row.title,
    instructor: row.instructor,
    units: row.units,
    color: row.color,
    createdAt: row.created_at,
  };
}

module.exports = { toSubject };
