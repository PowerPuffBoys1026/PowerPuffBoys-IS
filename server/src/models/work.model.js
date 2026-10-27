const db = require('../db');

const SELECT_WORK = `
  SELECT w.*, s.code AS subject_code, s.title AS subject_title, s.color
    FROM school_works w
    LEFT JOIN subjects s ON s.id = w.subject_id`;

const WorkModel = {
  subjectExistsAndOwned: (subjectId, userId) => {
    if (subjectId === undefined || subjectId === null) return true;
    const row = db.prepare('SELECT id FROM subjects WHERE id = ? AND user_id = ?').get(subjectId, userId);
    return Boolean(row);
  },

  findAllByUserId: (userId, { status, subjectId, dueBefore } = {}) => {
    const params = [userId];
    let sql = `${SELECT_WORK} WHERE w.user_id = ?`;

    if (status) {
      sql += ' AND w.status = ?';
      params.push(status);
    }
    if (subjectId) {
      sql += ' AND w.subject_id = ?';
      params.push(Number(subjectId));
    }
    if (dueBefore) {
      sql += " AND w.due_at IS NOT NULL AND date(w.due_at) <= date(?)";
      params.push(dueBefore);
    }

    sql += " ORDER BY w.status = 'done', COALESCE(w.due_at, '9999-12-31')";
    return db.prepare(sql).all(...params);
  },

  create: ({ userId, subjectId, title, type, dueAt, priority, status, notes }) => {
    const info = db
      .prepare(
        'INSERT INTO school_works (user_id, subject_id, title, type, due_at, priority, status, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      )
      .run(userId, subjectId ?? null, title, type ?? 'assignment', dueAt ?? null, priority ?? 'medium', status ?? 'todo', notes ?? null);
    return info.lastInsertRowid;
  },

  findByIdAndUserId: (id, userId) => {
    return db.prepare(`${SELECT_WORK} WHERE w.id = ? AND w.user_id = ?`).get(id, userId);
  },

  update: (id, updates, current) => {
    db.prepare(
      `UPDATE school_works
          SET subject_id = ?, title = ?, type = ?, due_at = ?, priority = ?, status = ?, notes = ?,
              updated_at = datetime('now')
        WHERE id = ?`,
    ).run(
      updates.subjectId !== undefined ? updates.subjectId : current.subject_id,
      updates.title ?? current.title,
      updates.type ?? current.type,
      updates.dueAt !== undefined ? updates.dueAt : current.due_at,
      updates.priority ?? current.priority,
      updates.status ?? current.status,
      updates.notes !== undefined ? updates.notes : current.notes,
      id,
    );
  },

  updateStatus: (id, status) => {
    db.prepare("UPDATE school_works SET status = ?, updated_at = datetime('now') WHERE id = ?").run(status, id);
  },

  delete: (id) => {
    return db.prepare('DELETE FROM school_works WHERE id = ?').run(id);
  },
};

module.exports = WorkModel;
