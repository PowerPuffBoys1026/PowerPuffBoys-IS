/**
 * View: shapes a subject row into the subject JSON payload.
 */
function toSubject(row) {
  return {
    id: row.id,
    code: row.code,
    title: row.title,
    instructor: row.instructor,
    instructorEmail: row.instructor_email ?? null,
    officeHours: row.office_hours ?? null,
    units: row.units,
    color: row.color,
    createdAt: row.created_at,
  };
}

module.exports = { toSubject };
