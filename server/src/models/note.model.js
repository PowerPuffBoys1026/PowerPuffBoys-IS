const { query } = require('../db');

const NoteModel = {
  findAllByUserId: async (userId, { search, tag, pinned } = {}) => {
    const params = [userId];
    let sql = 'SELECT * FROM notes WHERE user_id = $1';

    if (pinned !== undefined && pinned !== '') {
      const pinnedBool = pinned === 'true' || pinned === true;
      params.push(pinnedBool);
      sql += ` AND is_pinned = $${params.length}`;
    }

    if (tag) {
      const t = `%${tag}%`;
      params.push(t, `%,${t}`, `${t},%`);
      sql += ` AND (tags LIKE $${params.length - 2} OR tags LIKE $${params.length - 1} OR tags LIKE $${params.length})`;
    }

    if (search) {
      const s = `%${search}%`;
      params.push(s, s);
      sql += ` AND (title ILIKE $${params.length - 1} OR content ILIKE $${params.length})`;
    }

    sql += ' ORDER BY is_pinned DESC, updated_at DESC';
    const { rows } = await query(sql, params);
    return rows;
  },

  create: async ({ userId, title, content, isPinned, color, tags }) => {
    const { rows } = await query(
      `INSERT INTO notes (user_id, title, content, is_pinned, color, tags)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id`,
      [userId, title ?? 'Untitled', content ?? '', Boolean(isPinned), color ?? '#1C223D', tags ?? null],
    );
    return rows[0].id;
  },

  findByIdAndUserId: async (id, userId) => {
    const { rows } = await query(
      'SELECT * FROM notes WHERE id = $1 AND user_id = $2',
      [id, userId],
    );
    return rows[0];
  },

  update: async (id, updates, current) => {
    await query(
      `UPDATE notes
          SET title = $1, content = $2, is_pinned = $3, color = $4,
              tags = $5, updated_at = now()
        WHERE id = $6`,
      [
        updates.title ?? current.title,
        updates.content ?? current.content,
        updates.isPinned !== undefined ? Boolean(updates.isPinned) : current.is_pinned,
        updates.color !== undefined ? updates.color : current.color,
        updates.tags !== undefined ? updates.tags : current.tags,
        id,
      ],
    );
  },

  togglePin: async (id) => {
    await query(
      'UPDATE notes SET is_pinned = NOT is_pinned, updated_at = now() WHERE id = $1',
      [id],
    );
  },

  delete: async (id) => {
    const { rowCount } = await query('DELETE FROM notes WHERE id = $1', [id]);
    return rowCount;
  },
};

module.exports = NoteModel;
