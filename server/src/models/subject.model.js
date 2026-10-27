const db = require('../db');

const SubjectModel = {
  findAllByUserId: (userId) => {
    return db.prepare('SELECT * FROM subjects WHERE user_id = ? ORDER BY code').all(userId);
  },

  findById: (id) => {
    return db.prepare('SELECT * FROM subjects WHERE id = ?').get(id);
  },

  findByIdAndUserId: (id, userId) => {
    return db.prepare('SELECT * FROM subjects WHERE id = ? AND user_id = ?').get(id, userId);
  },

  create: ({ userId, code, title, instructor, units, color }) => {
    const info = db
      .prepare(
        'INSERT INTO subjects (user_id, code, title, instructor, units, color) VALUES (?, ?, ?, ?, ?, ?)',
      )
      .run(userId, code, title, instructor ?? null, units ?? 0, color ?? '#4F46E5');
    return SubjectModel.findByIdAndUserId(info.lastInsertRowid, userId);
  },

  update: (id, updates) => {
    const current = SubjectModel.findById(id);
    if (!current) return null;
    db.prepare('UPDATE subjects SET code = ?, title = ?, instructor = ?, units = ?, color = ? WHERE id = ?').run(
      updates.code ?? current.code,
      updates.title ?? current.title,
      updates.instructor !== undefined ? updates.instructor : current.instructor,
      updates.units ?? current.units,
      updates.color ?? current.color,
      id,
    );
    return SubjectModel.findById(id);
  },

  delete: (id) => {
    return db.prepare('DELETE FROM subjects WHERE id = ?').run(id);
  },
};

module.exports = SubjectModel;
