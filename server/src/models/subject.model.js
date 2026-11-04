const db = require('../db');

const SubjectModel = {
  findAllByUserId: async (userId) => {
    const result = await db.query('SELECT * FROM subjects WHERE user_id = $1 ORDER BY code', [userId]);
    return result.rows;
  },

  findById: async (id) => {
    const result = await db.query('SELECT * FROM subjects WHERE id = $1', [id]);
    return result.rows[0] || null;
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

  update: async (id, updates) => {
    const current = await SubjectModel.findById(id);
    if (!current) return null;
    const result = await db.query(
      'UPDATE subjects SET code = $1, title = $2, instructor = $3, units = $4, color = $5 WHERE id = $6 RETURNING *',
      [
        updates.code ?? current.code,
        updates.title ?? current.title,
        updates.instructor !== undefined ? updates.instructor : current.instructor,
        updates.units ?? current.units,
        updates.color ?? current.color,
        id,
      ],
    );
    return result.rows[0] || null;
  },

  delete: async (id) => {
    return db.query('DELETE FROM subjects WHERE id = $1', [id]);
  },
};

module.exports = SubjectModel;
