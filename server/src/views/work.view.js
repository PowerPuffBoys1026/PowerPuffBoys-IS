/**
 * View: shapes a school work row into the work JSON payload.
 */
function toWork(row) {
  return {
    id: row.id,
    title: row.title,
    subjectId: row.subject_id,
    subjectCode: row.subject_code ?? null,
    subjectTitle: row.subject_title ?? null,
    color: row.color ?? null,
    type: row.type,
    dueAt: row.due_at,
    priority: row.priority,
    status: row.status,
    notes: row.notes,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

module.exports = { toWork };
