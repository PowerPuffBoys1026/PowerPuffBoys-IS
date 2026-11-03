const { query } = require('../db');

const SubjectModel = {
  findAllByUserId: async (userId) => {
    const { rows } = await query(
      'SELECT * FROM subjects WHERE user_id = $1 ORDER BY code',
      [userId],
    );
    return rows;
  },

  findById: async (id) => {
    const { rows } = await query('SELECT * FROM subjects WHERE id = $1', [id]);
    return rows[0];
  },

  findByIdAndUserId: async (id, userId) => {
    const { rows } = await query(
      'SELECT * FROM subjects WHERE id = $1 AND user_id = $2',
      [id, userId],
    );
    return rows[0];
  },

  create: async ({ userId, code, title, instructor, units, color }) => {
    const { rows } = await query(
      `INSERT INTO subjects (user_id, code, title, instructor, units, color)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [userId, code, title, instructor ?? null, units ?? 0, color ?? '#4F46E5'],
    );
    return rows[0];
  },

  update: async (id, updates) => {
    const current = await SubjectModel.findById(id);
    if (!current) return null;

    const { rows } = await query(
      `UPDATE subjects
          SET code = $1, title = $2, instructor = $3, units = $4, color = $5
        WHERE id = $6
        RETURNING *`,
      [
        updates.code ?? current.code,
        updates.title ?? current.title,
        updates.instructor !== undefined ? updates.instructor : current.instructor,
        updates.units ?? current.units,
        updates.color ?? current.color,
        id,
      ],
    );
    return rows[0];
  },

  delete: async (id) => {
    const { rowCount } = await query('DELETE FROM subjects WHERE id = $1', [id]);
    return rowCount;
  },
};

module.exports = SubjectModel;
