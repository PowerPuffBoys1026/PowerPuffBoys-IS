const db = require('../db');

const AttendanceModel = {
  subjectExistsAndOwned: (subjectId, userId) => {
    const row = db.prepare('SELECT id FROM subjects WHERE id = ? AND user_id = ?').get(subjectId, userId);
    return Boolean(row);
  },

  findDuplicate: (subjectId, date, slotId) => {
    if (slotId === null || slotId === undefined) {
      return db
        .prepare(
          `SELECT id FROM attendance_records
            WHERE subject_id = ? AND date = ? AND slot_id IS NULL`,
        )
        .get(subjectId, date);
    }
    return db
      .prepare(
        `SELECT id FROM attendance_records
          WHERE subject_id = ? AND date = ? AND slot_id = ?`,
      )
      .get(subjectId, date, slotId);
  },

  create: ({ subjectId, slotId, date, status, note }) => {
    const info = db
      .prepare('INSERT INTO attendance_records (subject_id, slot_id, date, status, note) VALUES (?, ?, ?, ?, ?)')
      .run(subjectId, slotId ?? null, date, status, note ?? null);
    return info.lastInsertRowid;
  },

  findByIdAndUserId: (id, userId) => {
    const row = db
      .prepare(
        `SELECT a.* FROM attendance_records a
          JOIN subjects s ON s.id = a.subject_id
         WHERE a.id = ? AND s.user_id = ?`,
      )
      .get(id, userId);
    return row;
  },

  findAllByUserId: (userId, { subjectId, from, to } = {}) => {
    const params = [userId];
    let sql = `SELECT a.* FROM attendance_records a
                 JOIN subjects s ON s.id = a.subject_id
                WHERE s.user_id = ?`;

    if (subjectId) {
      sql += ' AND a.subject_id = ?';
      params.push(Number(subjectId));
    }
    if (from) {
      sql += ' AND a.date >= ?';
      params.push(from);
    }
    if (to) {
      sql += ' AND a.date <= ?';
      params.push(to);
    }

    sql += ' ORDER BY a.date DESC';
    return db.prepare(sql).all(...params);
  },

  update: (id, updates, current) => {
    db.prepare(
      'UPDATE attendance_records SET subject_id = ?, slot_id = ?, date = ?, status = ?, note = ? WHERE id = ?',
    ).run(
      updates.subjectId ?? current.subject_id,
      updates.slotId !== undefined ? updates.slotId : current.slot_id,
      updates.date ?? current.date,
      updates.status ?? current.status,
      updates.note !== undefined ? updates.note : current.note,
      id,
    );
  },

  delete: (id) => {
    return db.prepare('DELETE FROM attendance_records WHERE id = ?').run(id);
  },
};

module.exports = AttendanceModel;
