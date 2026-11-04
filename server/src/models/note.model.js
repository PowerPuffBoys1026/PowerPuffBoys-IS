const db = require('../db');

const NoteModel = {
  findAllByUserId: async (userId, { search, tag, pinned } = {}) => {
    const params = [userId];
    let sql = 'SELECT * FROM notes WHERE user_id = $1';

    if (pinned !== undefined && pinned !== '') {
      sql += ` AND is_pinned = $${params.length + 1}`;
      params.push(pinned === 'true' || pinned === true ? 1 : 0);
    }

    if (tag) {
      sql += ` AND (tags LIKE $${params.length + 1} OR tags LIKE $${params.length + 2} OR tags LIKE $${params.length + 3})`;
      const t = `%${tag}%`;
      params.push(t, `%,${t}`, `${t},%`);
    }

    if (search) {
      sql += ` AND (title LIKE $${params.length + 1} OR content LIKE $${params.length + 2})`;
      const s = `%${search}%`;
      params.push(s, s);
    }

    sql += ' ORDER BY is_pinned DESC, updated_at DESC';
    const result = await db.query(sql, params);
    return result.rows;
  },

  create: async ({ userId, title, content, isPinned, color, tags }) => {
    const result = await db.query(
      'INSERT INTO notes (user_id, title, content, is_pinned, color, tags) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id',
      [userId, title ?? 'Untitled', content ?? '', isPinned ? 1 : 0, color ?? '#1C223D', tags ?? null],
    );
    return result.rows[0].id;
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query('SELECT * FROM notes WHERE id = $1 AND user_id = $2', [id, userId]);
    return result.rows[0] || null;
  },

  update: async (id, updates, current) => {
    await db.query(
      `UPDATE notes
          SET title = $1, content = $2, is_pinned = $3, color = $4, tags = $5, updated_at = NOW()
        WHERE id = $6`,
      [
        updates.title ?? current.title,
        updates.content ?? current.content,
        updates.isPinned !== undefined ? (updates.isPinned ? 1 : 0) : current.is_pinned,
        updates.color !== undefined ? updates.color : current.color,
        updates.tags !== undefined ? updates.tags : current.tags,
        id,
      ],
    );
  },

  togglePin: async (id) => {
    await db.query("UPDATE notes SET is_pinned = CASE WHEN is_pinned = 1 THEN 0 ELSE 1 END, updated_at = NOW() WHERE id = $1", [id]);
  },

  delete: async (id) => {
    return db.query('DELETE FROM notes WHERE id = $1', [id]);
  },
};

module.exports = NoteModel;
