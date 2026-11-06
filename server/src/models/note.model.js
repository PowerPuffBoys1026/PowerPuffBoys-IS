const db = require('../db');

/** Escape LIKE wildcards so user input is matched literally. */
function escapeLike(term) {
  return term.replace(/[\\%_]/g, '\\$&');
}

const NoteModel = {
  findAllByUserId: async (userId, { search, tag, pinned, limit, offset } = {}) => {
    const params = [userId];
    let sql = 'SELECT * FROM notes WHERE user_id = $1';

    if (pinned !== undefined && pinned !== '') {
      sql += ` AND is_pinned = $${params.length + 1}`;
      params.push(pinned === 'true' || pinned === true);
    }

    if (tag) {
      sql += ` AND (tags LIKE $${params.length + 1} ESCAPE '\\'
                    OR tags LIKE $${params.length + 2} ESCAPE '\\'
                    OR tags LIKE $${params.length + 3} ESCAPE '\\')`;
      const t = `%${escapeLike(tag)}%`;
      params.push(t, `%,${t}`, `${t},%`);
    }

    if (search) {
      sql += ` AND (title LIKE $${params.length + 1} ESCAPE '\\'
                OR content LIKE $${params.length + 2} ESCAPE '\\')`;
      const s = `%${escapeLike(search)}%`;
      params.push(s, s);
    }

    sql += ' ORDER BY is_pinned DESC, updated_at DESC';

    if (limit !== undefined) {
      sql += ` LIMIT $${params.length + 1}`;
      params.push(limit);
    }
    if (offset !== undefined) {
      sql += ` OFFSET $${params.length + 1}`;
      params.push(offset);
    }

    const result = await db.query(sql, params);
    return result.rows;
  },

  create: async ({ userId, title, content, isPinned, color, tags }) => {
    const result = await db.query(
      `INSERT INTO notes (user_id, title, content, is_pinned, color, tags)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [userId, title ?? 'Untitled', content ?? '', Boolean(isPinned), color ?? '#1C223D', tags ?? null],
    );
    return result.rows[0];
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query('SELECT * FROM notes WHERE id = $1 AND user_id = $2', [id, userId]);
    return result.rows[0] || null;
  },

  /** Update a note owned by `userId`; returns the updated row or null. */
  update: async (id, updates, current, userId) => {
    const result = await db.query(
      `UPDATE notes
          SET title = $1, content = $2, is_pinned = $3, color = $4, tags = $5, updated_at = NOW()
        WHERE id = $6 AND user_id = $7
        RETURNING *`,
      [
        updates.title ?? current.title,
        updates.content ?? current.content,
        updates.isPinned !== undefined ? updates.isPinned : current.is_pinned,
        updates.color !== undefined ? updates.color : current.color,
        updates.tags !== undefined ? updates.tags : current.tags,
        id,
        userId,
      ],
    );
    return result.rows[0] || null;
  },

  togglePin: async (id, userId) => {
    const result = await db.query(
      `UPDATE notes
          SET is_pinned = NOT is_pinned, updated_at = NOW()
        WHERE id = $1 AND user_id = $2
        RETURNING *`,
      [id, userId],
    );
    return result.rows[0] || null;
  },

  delete: (id, userId) => {
    return db.query('DELETE FROM notes WHERE id = $1 AND user_id = $2', [id, userId]);
  },
};

module.exports = NoteModel;
