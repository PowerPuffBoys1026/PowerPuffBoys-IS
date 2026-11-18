function toNote(row) {
  return {
    id: row.id,
    subjectId: row.subject_id ?? null,
    subjectCode: row.subject_code ?? null,
    subjectTitle: row.subject_title ?? null,
    subjectColor: row.subject_color ?? row.color ?? null,
    title: row.title,
    content: row.content,
    isPinned: Boolean(row.is_pinned),
    color: row.color,
    tags: row.tags,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

module.exports = { toNote };
