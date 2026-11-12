const db = require('../db');

const SubjectModel = {
  findAllByUserId: async (userId, { limit, offset } = {}) => {
    const result = await db.query('SELECT * FROM fn_subjects_list($1, $2, $3)', [userId, limit ?? null, offset ?? null]);
    return result.rows;
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query('SELECT * FROM fn_subject_get($1, $2)', [id, userId]);
    return result.rows[0] || null;
  },

  create: async ({ userId, code, title, instructor, instructorEmail, officeHours, units, color }) => {
    const result = await db.query(
      'SELECT * FROM fn_subject_create($1, $2, $3, $4, $5, $6, $7, $8)',
      [userId, code, title, instructor ?? null, instructorEmail ?? null, officeHours ?? null, units ?? 0, color ?? '#4F46E5'],
    );
    return result.rows[0];
  },

  update: async (id, updates, userId) => {
    const result = await db.query(
      'SELECT * FROM fn_subject_update($1, $2, $3, $4, $5, $6, $7, $8, $9)',
      [
        id,
        userId,
        updates.code,
        updates.title,
        updates.instructor,
        updates.instructorEmail,
        updates.officeHours,
        updates.units,
        updates.color,
      ],
    );
    return result.rows[0] || null;
  },

  delete: (id, userId) => db.query('SELECT fn_subject_delete($1, $2) AS count', [id, userId]),
};

module.exports = SubjectModel;
