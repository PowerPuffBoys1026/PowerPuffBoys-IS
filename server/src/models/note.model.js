const db = require('../db');

const NoteModel = {
  findAllByUserId: (userId, { search, tag, pinned } = {}) => {
    const params = [userId];
    let sql = 'SELECT * FROM notes WHERE user_id = ?';

    if (pinned !== undefined && pinned !== '') {
      sql += ' AND is_pinned = ?';
      params.push(pinned === 'true' || pinned === true ? 1 : 0);
    }

    if (tag) {
      sql += " AND (tags LIKE ? OR tags LIKE ? OR tags LIKE ?)";
      const t = `%${tag}%`;
      params.push(t, `%,${t}`, `${t},%`);
    }

    if (search) {
      sql += ' AND (title LIKE ? OR content LIKE ?)';
      const s = `%${search}%`;
      params.push(s, s);
    }

    sql += ' ORDER BY is_pinned DESC, updated_at DESC';
    return db.prepare(sql).all(...params);
  },

  create: ({ userId, title, content, isPinned, color, tags }) => {
    const info = db
      .prepare(
        'INSERT INTO notes (user_id, title, content, is_pinned, color, tags) VALUES (?, ?, ?, ?, ?, ?)',
      )
      .run(userId, title ?? 'Untitled', content ?? '', isPinned ? 1 : 0, color ?? '#1C223D', tags ?? null);
    return info.lastInsertRowid;
  },

  findByIdAndUserId: (id, userId) => {
    return db.prepare('SELECT * FROM notes WHERE id = ? AND user_id = ?').get(id, userId);
  },

  update: (id, updates, current) => {
    db.prepare(
      `UPDATE notes
          SET title = ?, content = ?, is_pinned = ?, color = ?, tags = ?, updated_at = datetime('now')
        WHERE id = ?`,
    ).run(
      updates.title ?? current.title,
      updates.content ?? current.content,
      updates.isPinned !== undefined ? (updates.isPinned ? 1 : 0) : current.is_pinned,
      updates.color !== undefined ? updates.color : current.color,
      updates.tags !== undefined ? updates.tags : current.tags,
      id,
    );
  },

  togglePin: (id) => {
    db.prepare("UPDATE notes SET is_pinned = CASE WHEN is_pinned = 1 THEN 0 ELSE 1 END, updated_at = datetime('now') WHERE id = ?").run(id);
  },

  delete: (id) => {
    return db.prepare('DELETE FROM notes WHERE id = ?').run(id);
  },
};

module.exports = NoteModel;
