const db = require('../db');

const UserModel = {
  findByEmail: async (email) => {
    const result = await db.query('SELECT * FROM fn_user_find_by_email($1)', [email]);
    return result.rows[0] || null;
  },

  findById: async (id) => {
    const result = await db.query('SELECT * FROM fn_user_find_by_id($1)', [id]);
    return result.rows[0] || null;
  },

  create: async ({ email, passwordHash, fullName, studentNo, course, yearLevel }) => {
    const result = await db.query(
      'SELECT * FROM fn_user_create($1, $2, $3, $4, $5, $6)',
      [email, passwordHash, fullName, studentNo ?? null, course ?? null, yearLevel ?? null],
    );
    return result.rows[0];
  },

  updateProfile: async (id, { fullName, studentNo, course, yearLevel }) => {
    const result = await db.query(
      'SELECT * FROM fn_user_update_profile($1, $2, $3, $4, $5)',
      [id, fullName, studentNo ?? null, course ?? null, yearLevel ?? null],
    );
    return result.rows[0] || null;
  },

  updatePasswordHash: async (id, passwordHash) => {
    await db.query('SELECT fn_user_update_password($1, $2)', [id, passwordHash]);
  },

  existsByEmail: async (email) => {
    const result = await db.query('SELECT fn_user_exists_by_email($1) AS exists', [email]);
    return Boolean(result.rows[0]?.exists);
  },
};

module.exports = UserModel;
