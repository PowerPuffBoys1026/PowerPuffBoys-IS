const db = require('../db');

const SubjectModel = {
  findAllByUserId: async (userId, { limit, offset } = {}) => {
    const params = [userId];
    let sql = 'SELECT * FROM subjects WHERE user_id = $1 ORDER BY code';
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

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query('SELECT * FROM subjects WHERE id = $1 AND user_id = $2', [id, userId]);
    return result.rows[0] || null;
  },

  create: async ({ userId, code, title, instructor, units, color }) => {
    const result = await db.query(
      'INSERT INTO subjects (user_id, code, title, instructor, units, color) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [userId, code, title, instructor ?? null, units ?? 0, color ?? '#4F46E5'],
    );
    return result.rows[0];
  },

  /** Update a subject owned by `userId`; returns the updated row or null. */
  update: async (id, updates, userId) => {
    const result = await db.query(
      `UPDATE subjects
          SET code = $1, title = $2, instructor = $3, units = $4, color = $5
        WHERE id = $6 AND user_id = $7
        RETURNING *`,
      [
        updates.code,
        updates.title,
        updates.instructor,
        updates.units,
        updates.color,
        id,
        userId,
      ],
    );
    return result.rows[0] || null;
  },

  delete: (id, userId) => {
    return db.query('DELETE FROM subjects WHERE id = $1 AND user_id = $2', [id, userId]);
  },
};

module.exports = SubjectModel;
