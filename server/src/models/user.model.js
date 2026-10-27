const db = require('../db');

const UserModel = {
  findByEmail: (email) => {
    return db.prepare('SELECT * FROM users WHERE email = ?').get(email);
  },

  findById: (id) => {
    return db.prepare('SELECT * FROM users WHERE id = ?').get(id);
  },

  create: ({ email, passwordHash, fullName, studentNo, course }) => {
    const info = db
      .prepare(
        'INSERT INTO users (email, password_hash, full_name, student_no, course) VALUES (?, ?, ?, ?, ?)',
      )
      .run(email, passwordHash, fullName, studentNo ?? null, course ?? null);
    return UserModel.findById(info.lastInsertRowid);
  },

  existsByEmail: (email) => {
    const row = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    return Boolean(row);
  },
};

module.exports = UserModel;
