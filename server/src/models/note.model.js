const db = require('../db');

/** Escape LIKE wildcards so user input is matched literally. */
function escapeLike(term) {
  return term.replace(/[\\%_]/g, '\\$&');
}

const SELECT_NOTE = `
  SELECT n.*, s.code AS subject_code, s.title AS subject_title, s.color AS subject_color
    FROM notes n
    LEFT JOIN subjects s ON s.id = n.subject_id AND s.user_id = n.user_id`;

const NoteModel = {
  findAllByUserId: async (userId, { search, tag, pinned, subjectId, limit, offset } = {}) => {
    const params = [userId];
    let sql = `${SELECT_NOTE} WHERE n.user_id = $1`;

    if (subjectId !== undefined && subjectId !== null && subjectId !== '') {
      sql += ` AND n.subject_id = $${params.length + 1}`;
      params.push(Number(subjectId));
    }
    if (pinned !== undefined && pinned !== '') {
      sql += ` AND n.is_pinned = $${params.length + 1}`;
      params.push(pinned === 'true' || pinned === true);
    }
    if (tag) {
      sql += ` AND n.tags ILIKE $${params.length + 1}`;
      params.push(`%${escapeLike(tag)}%`);
    }
    if (search) {
      sql += ` AND (n.title ILIKE $${params.length + 1} OR n.content ILIKE $${params.length + 2})`;
      const s = `%${escapeLike(search)}%`;
      params.push(s, s);
    }
    sql += ' ORDER BY n.is_pinned DESC, n.updated_at DESC';
    if (limit !== undefined) { sql += ` LIMIT $${params.length + 1}`; params.push(limit); }
    if (offset !== undefined) { sql += ` OFFSET $${params.length + 1}`; params.push(offset); }
    const result = await db.query(sql, params);
    return result.rows;
  },

  create: async ({ userId, subjectId, title, content, isPinned, color, tags }) => {
    const result = await db.query(
      `INSERT INTO notes (user_id, subject_id, title, content, is_pinned, color, tags)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [userId, subjectId ?? null, title ?? 'Untitled', content ?? '', Boolean(isPinned), color ?? '#1C223D', tags ?? null],
    );
    const joined = await db.query(`${SELECT_NOTE} WHERE n.id = $1`, [result.rows[0].id]);
    return joined.rows[0] || result.rows[0];
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query(`${SELECT_NOTE} WHERE n.id = $1 AND n.user_id = $2`, [id, userId]);
    return result.rows[0] || null;
  },

  update: async (id, updates, current, userId) => {
    const result = await db.query(
      `UPDATE notes
          SET subject_id = $1, title = $2, content = $3, is_pinned = $4, color = $5, tags = $6, updated_at = NOW()
        WHERE id = $7 AND user_id = $8
        RETURNING *`,
      [
        updates.subjectId !== undefined ? updates.subjectId : (current.subject_id ?? null),
        updates.title ?? current.title,
        updates.content ?? current.content,
        updates.isPinned !== undefined ? updates.isPinned : current.is_pinned,
        updates.color !== undefined ? updates.color : current.color,
        updates.tags !== undefined ? updates.tags : current.tags,
        id,
        userId,
      ],
    );
    if (!result.rows[0]) return null;
    const joined = await db.query(`${SELECT_NOTE} WHERE n.id = $1`, [id]);
    return joined.rows[0] || result.rows[0];
  },

  togglePin: async (id, userId) => {
    const result = await db.query(
      `UPDATE notes SET is_pinned = NOT is_pinned, updated_at = NOW() WHERE id = $1 AND user_id = $2 RETURNING *`,
      [id, userId],
    );
    if (!result.rows[0]) return null;
    const joined = await db.query(`${SELECT_NOTE} WHERE n.id = $1`, [id]);
    return joined.rows[0] || result.rows[0];
  },

  delete: (id, userId) => db.query('DELETE FROM notes WHERE id = $1 AND user_id = $2', [id, userId]),
  subjectExistsAndOwned: async (subjectId, userId) => {
    if (subjectId == null) return true;
    const r = await db.query('SELECT id FROM subjects WHERE id = $1 AND user_id = $2', [subjectId, userId]);
    return r.rowCount > 0;
  },
};

module.exports = NoteModel;
