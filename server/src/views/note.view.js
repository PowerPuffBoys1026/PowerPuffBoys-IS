function toNote(row) {
  return {
    id: row.id,
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
