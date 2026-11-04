const db = require('../db');

const AttendanceModel = {
  subjectExistsAndOwned: async (subjectId, userId) => {
    const result = await db.query('SELECT id FROM subjects WHERE id = $1 AND user_id = $2', [subjectId, userId]);
    return result.rowCount > 0;
  },

  findDuplicate: async (subjectId, date, slotId) => {
    let result;
    if (slotId === null || slotId === undefined) {
      result = await db.query(
        `SELECT id FROM attendance_records
          WHERE subject_id = $1 AND date = $2 AND slot_id IS NULL`,
        [subjectId, date],
      );
    } else {
      result = await db.query(
        `SELECT id FROM attendance_records
          WHERE subject_id = $1 AND date = $2 AND slot_id = $3`,
        [subjectId, date, slotId],
      );
    }
    return result.rows[0] || null;
  },

  create: async ({ subjectId, slotId, date, status, note }) => {
    const result = await db.query(
      'INSERT INTO attendance_records (subject_id, slot_id, date, status, note) VALUES ($1, $2, $3, $4, $5) RETURNING id',
      [subjectId, slotId ?? null, date, status, note ?? null],
    );
    return result.rows[0].id;
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query(
      `SELECT a.* FROM attendance_records a
        JOIN subjects s ON s.id = a.subject_id
       WHERE a.id = $1 AND s.user_id = $2`,
      [id, userId],
    );
    return result.rows[0] || null;
  },

  findAllByUserId: async (userId, { subjectId, from, to } = {}) => {
    const params = [userId];
    let sql = `SELECT a.* FROM attendance_records a
                 JOIN subjects s ON s.id = a.subject_id
                WHERE s.user_id = $1`;

    if (subjectId) {
      sql += ` AND a.subject_id = $${params.length + 1}`;
      params.push(Number(subjectId));
    }
    if (from) {
      sql += ` AND a.date >= $${params.length + 1}`;
      params.push(from);
    }
    if (to) {
      sql += ` AND a.date <= $${params.length + 1}`;
      params.push(to);
    }

    sql += ' ORDER BY a.date DESC';
    const result = await db.query(sql, params);
    return result.rows;
  },

  update: async (id, updates, current) => {
    await db.query(
      'UPDATE attendance_records SET subject_id = $1, slot_id = $2, date = $3, status = $4, note = $5 WHERE id = $6',
      [
        updates.subjectId ?? current.subject_id,
        updates.slotId !== undefined ? updates.slotId : current.slot_id,
        updates.date ?? current.date,
        updates.status ?? current.status,
        updates.note !== undefined ? updates.note : current.note,
        id,
      ],
    );
  },

  delete: (id) => {
    return db.query('DELETE FROM attendance_records WHERE id = $1', [id]);
  },
};

module.exports = AttendanceModel;
