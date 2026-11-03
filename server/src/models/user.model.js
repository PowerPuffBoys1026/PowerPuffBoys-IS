const { query } = require('../db');

const UserModel = {
  findByEmail: async (email) => {
    const { rows } = await query('SELECT * FROM users WHERE email = $1', [email]);
    return rows[0];
  },

  findById: async (id) => {
    const { rows } = await query('SELECT * FROM users WHERE id = $1', [id]);
    return rows[0];
  },

  create: async ({ email, passwordHash, fullName, studentNo, course }) => {
    const { rows } = await query(
      `INSERT INTO users (email, password_hash, full_name, student_no, course)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [email, passwordHash, fullName, studentNo ?? null, course ?? null],
    );
    return rows[0];
  },

  existsByEmail: async (email) => {
    const { rowCount } = await query('SELECT 1 FROM users WHERE email = $1', [email]);
    return rowCount > 0;
  },
};

module.exports = UserModel;
