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

  findAllByUserId: async (userId, { status, subjectId, dueBefore, limit, offset } = {}) => {
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
      sql += ` AND w.due_at IS NOT NULL AND w.due_at::date <= $${params.length + 1}::date`;
      params.push(dueBefore);
    }

    sql += " ORDER BY (w.status = 'done'), COALESCE(w.due_at, '9999-12-31'::timestamptz)";

    if (limit !== undefined) {
      sql += ` LIMIT $${params.length + 1}`;
      params.push(limit);
    }
    if (offset !== undefined) {
      sql += ` OFFSET $${params.length + 1}`;
      params.push(offset);
    }

    const result = await db.query(sql, params);
    return result.rows;
  },

  create: async ({ userId, subjectId, title, type, dueAt, priority, status, notes }) => {
    const result = await db.query(
      `WITH inserted AS (
         INSERT INTO school_works (user_id, subject_id, title, type, due_at, priority, status, notes)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *
       )
       SELECT i.*, s.code AS subject_code, s.title AS subject_title, s.color
         FROM inserted i
         LEFT JOIN subjects s ON s.id = i.subject_id`,
      [userId, subjectId ?? null, title, type ?? 'assignment', dueAt ?? null, priority ?? 'medium', status ?? 'todo', notes ?? null],
    );
    return result.rows[0];
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query(`${SELECT_WORK} WHERE w.id = $1 AND w.user_id = $2`, [id, userId]);
    return result.rows[0] || null;
  },

  /** Update a work owned by `userId`; returns the joined row or null. */
  update: async (id, updates, current, userId) => {
    const result = await db.query(
      `WITH updated AS (
         UPDATE school_works w
            SET subject_id = $1, title = $2, type = $3, due_at = $4, priority = $5,
                status = $6, notes = $7, updated_at = NOW()
          WHERE w.id = $8 AND w.user_id = $9
          RETURNING w.*
       )
       SELECT u.*, s.code AS subject_code, s.title AS subject_title, s.color
         FROM updated u
         LEFT JOIN subjects s ON s.id = u.subject_id`,
      [
        updates.subjectId !== undefined ? updates.subjectId : current.subject_id,
        updates.title ?? current.title,
        updates.type ?? current.type,
        updates.dueAt !== undefined ? updates.dueAt : current.due_at,
        updates.priority ?? current.priority,
        updates.status ?? current.status,
        updates.notes !== undefined ? updates.notes : current.notes,
        id,
        userId,
      ],
    );
    return result.rows[0] || null;
  },

  updateStatus: async (id, status, userId) => {
    const result = await db.query(
      `WITH updated AS (
         UPDATE school_works w
            SET status = $1, updated_at = NOW()
          WHERE w.id = $2 AND w.user_id = $3
          RETURNING w.*
       )
       SELECT u.*, s.code AS subject_code, s.title AS subject_title, s.color
         FROM updated u
         LEFT JOIN subjects s ON s.id = u.subject_id`,
      [status, id, userId],
    );
    return result.rows[0] || null;
  },

  delete: (id, userId) => {
    return db.query('DELETE FROM school_works WHERE id = $1 AND user_id = $2', [id, userId]);
  },
};

module.exports = WorkModel;
