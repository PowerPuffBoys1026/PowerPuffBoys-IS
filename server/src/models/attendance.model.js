const { query } = require('../db');

const AttendanceModel = {
  subjectExistsAndOwned: async (subjectId, userId) => {
    const { rowCount } = await query(
      'SELECT 1 FROM subjects WHERE id = $1 AND user_id = $2',
      [subjectId, userId],
    );
    return rowCount > 0;
  },

  findDuplicate: async (subjectId, date, slotId) => {
    if (slotId === null || slotId === undefined) {
      const { rows } = await query(
        `SELECT id FROM attendance_records
          WHERE subject_id = $1 AND date = $2 AND slot_id IS NULL`,
        [subjectId, date],
      );
      return rows[0];
    }

    const { rows } = await query(
      `SELECT id FROM attendance_records
        WHERE subject_id = $1 AND date = $2 AND slot_id = $3`,
      [subjectId, date, slotId],
    );
    return rows[0];
  },

  create: async ({ subjectId, slotId, date, status, note }) => {
    const { rows } = await query(
      `INSERT INTO attendance_records (subject_id, slot_id, date, status, note)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [subjectId, slotId ?? null, date, status, note ?? null],
    );
    return rows[0].id;
  },

  findByIdAndUserId: async (id, userId) => {
    const { rows } = await query(
      `SELECT a.id, a.subject_id, a.slot_id, a.date::text AS date,
              a.status, a.note, a.created_at
         FROM attendance_records a
         JOIN subjects s ON s.id = a.subject_id
        WHERE a.id = $1 AND s.user_id = $2`,
      [id, userId],
    );
    return rows[0];
  },

  findAllByUserId: async (userId, { subjectId, from, to } = {}) => {
    const params = [userId];
    let sql = `SELECT a.id, a.subject_id, a.slot_id, a.date::text AS date,
                      a.status, a.note, a.created_at
                 FROM attendance_records a
                 JOIN subjects s ON s.id = a.subject_id
                WHERE s.user_id = $1`;

    if (subjectId) {
      params.push(Number(subjectId));
      sql += ` AND a.subject_id = $${params.length}`;
    }
    if (from) {
      params.push(from);
      sql += ` AND a.date >= $${params.length}`;
    }
    if (to) {
      params.push(to);
      sql += ` AND a.date <= $${params.length}`;
    }

    sql += ' ORDER BY a.date DESC';
    const { rows } = await query(sql, params);
    return rows;
  },

  update: async (id, updates, current) => {
    await query(
      `UPDATE attendance_records
          SET subject_id = $1, slot_id = $2, date = $3, status = $4, note = $5
        WHERE id = $6`,
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

  delete: async (id) => {
    const { rowCount } = await query('DELETE FROM attendance_records WHERE id = $1', [id]);
    return rowCount;
  },
};

module.exports = AttendanceModel;
