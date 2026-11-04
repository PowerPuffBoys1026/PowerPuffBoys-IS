const db = require('../db');

const SELECT_WORK = `
  SELECT w.*, s.code AS subject_code, s.title AS subject_title, s.color
    FROM school_works w
    LEFT JOIN subjects s ON s.id = w.subject_id`;

const WorkModel = {
  subjectExistsAndOwned: async (subjectId, userId) => {
    if (subjectId === undefined || subjectId === null) return true;
    const result = await db.query('SELECT id FROM subjects WHERE id = $1 AND user_id = $2', [subjectId, userId]);
    return result.rowCount > 0;
  },

  findAllByUserId: async (userId, { status, subjectId, dueBefore } = {}) => {
    const params = [userId];
    let sql = `${SELECT_WORK} WHERE w.user_id = $1`;

    if (status) {
      sql += ` AND w.status = $${params.length + 1}`;
      params.push(status);
    }
    if (subjectId) {
      sql += ` AND w.subject_id = $${params.length + 1}`;
      params.push(Number(subjectId));
    }
    if (dueBefore) {
      sql += ` AND w.due_at IS NOT NULL AND LEFT(w.due_at, 10)::date <= $${params.length + 1}::date`;
      params.push(dueBefore);
    }

    sql += " ORDER BY (w.status = 'done'), COALESCE(w.due_at, '9999-12-31')";
    const result = await db.query(sql, params);
    return result.rows;
  },

  create: async ({ userId, subjectId, title, type, dueAt, priority, status, notes }) => {
    const result = await db.query(
      'INSERT INTO school_works (user_id, subject_id, title, type, due_at, priority, status, notes) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id',
      [userId, subjectId ?? null, title, type ?? 'assignment', dueAt ?? null, priority ?? 'medium', status ?? 'todo', notes ?? null],
    );
    return result.rows[0].id;
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query(`${SELECT_WORK} WHERE w.id = $1 AND w.user_id = $2`, [id, userId]);
    return result.rows[0] || null;
  },

  update: async (id, updates, current) => {
    await db.query(
      `UPDATE school_works
          SET subject_id = $1, title = $2, type = $3, due_at = $4, priority = $5, status = $6, notes = $7,
              updated_at = NOW()
        WHERE id = $8`,
      [
        updates.subjectId !== undefined ? updates.subjectId : current.subject_id,
        updates.title ?? current.title,
        updates.type ?? current.type,
        updates.dueAt !== undefined ? updates.dueAt : current.due_at,
        updates.priority ?? current.priority,
        updates.status ?? current.status,
        updates.notes !== undefined ? updates.notes : current.notes,
        id,
      ],
    );
  },

  updateStatus: (id, status) => {
    return db.query('UPDATE school_works SET status = $1, updated_at = NOW() WHERE id = $2', [status, id]);
  },

  delete: (id) => {
    return db.query('DELETE FROM school_works WHERE id = $1', [id]);
  },
};

module.exports = WorkModel;
