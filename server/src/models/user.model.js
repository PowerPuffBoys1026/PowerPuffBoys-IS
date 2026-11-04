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

  create: async ({ email, passwordHash, fullName, studentNo, course }) => {
    const result = await db.query(
      'INSERT INTO users (email, password_hash, full_name, student_no, course) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [email, passwordHash, fullName, studentNo ?? null, course ?? null],
    );
    return result.rows[0];
  },

  existsByEmail: async (email) => {
    const result = await db.query('SELECT id FROM users WHERE email = $1', [email]);
    return result.rows.length > 0;
  },
};

module.exports = UserModel;
