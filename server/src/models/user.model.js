const db = require('../db');

const UserModel = {
  findByEmail: async (email) => {
    const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);
    return result.rows[0] || null;
  },

  findById: async (id) => {
    const result = await db.query('SELECT * FROM users WHERE id = $1', [id]);
    return result.rows[0] || null;
  },

  create: async ({ email, passwordHash, fullName, studentNo, course, yearLevel }) => {
    const result = await db.query(
      'INSERT INTO users (email, password_hash, full_name, student_no, course, year_level) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [email, passwordHash, fullName, studentNo ?? null, course ?? null, yearLevel ?? null],
    );
    return result.rows[0];
  },

  updateProfile: async (id, { fullName, studentNo, course, yearLevel }) => {
    const result = await db.query(
      'UPDATE users SET full_name = $1, student_no = $2, course = $3, year_level = $4 WHERE id = $5 RETURNING *',
      [fullName, studentNo ?? null, course ?? null, yearLevel ?? null, id],
    );
    return result.rows[0] || null;
  },

  updatePasswordHash: async (id, passwordHash) => {
    await db.query('UPDATE users SET password_hash = $1 WHERE id = $2', [passwordHash, id]);
  },

  existsByEmail: async (email) => {
    const result = await db.query('SELECT id FROM users WHERE email = $1', [email]);
    return result.rows.length > 0;
  },
};

module.exports = UserModel;
