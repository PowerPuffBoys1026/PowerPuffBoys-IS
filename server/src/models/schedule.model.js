const db = require('../db');

const SELECT_SLOT = `
  SELECT sc.*, s.code AS subject_code, s.title AS subject_title, s.color
    FROM schedule_slots sc
    JOIN subjects s ON s.id = sc.subject_id`;

const ScheduleModel = {
  findAllByUserId: (userId, day) => {
    const params = [userId];
    let sql = `${SELECT_SLOT} WHERE s.user_id = ?`;

    if (day !== undefined && day !== '') {
      const dayNum = Number(day);
      sql += ' AND sc.day_of_week = ?';
      params.push(dayNum);
    }

    sql += ' ORDER BY sc.day_of_week, sc.start_time';
    return db.prepare(sql).all(...params);
  },

  findById: (id) => {
    return db.prepare(`${SELECT_SLOT} WHERE sc.id = ?`).get(id);
  },

  findByIdAndUserId: (id, userId) => {
    return db.prepare(`${SELECT_SLOT} WHERE sc.id = ? AND s.user_id = ?`).get(id, userId);
  },

  create: ({ subjectId, dayOfWeek, startTime, endTime, room, modality }) => {
    const info = db
      .prepare(
        'INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time, room, modality) VALUES (?, ?, ?, ?, ?, ?)',
      )
      .run(subjectId, dayOfWeek, startTime, endTime, room ?? null, modality ?? null);
    return info.lastInsertRowid;
  },

  update: (id, updates, current) => {
    db.prepare(
      'UPDATE schedule_slots SET subject_id = ?, day_of_week = ?, start_time = ?, end_time = ?, room = ?, modality = ? WHERE id = ?',
    ).run(
      updates.subjectId ?? current.subject_id,
      updates.dayOfWeek ?? current.day_of_week,
      updates.startTime ?? current.start_time,
      updates.endTime ?? current.end_time,
      updates.room !== undefined ? updates.room : current.room,
      updates.modality !== undefined ? updates.modality : current.modality,
      id,
    );
  },

  delete: (id) => {
    return db.prepare('DELETE FROM schedule_slots WHERE id = ?').run(id);
  },

  subjectExistsAndOwned: (subjectId, userId) => {
    const row = db.prepare('SELECT id FROM subjects WHERE id = ? AND user_id = ?').get(subjectId, userId);
    return Boolean(row);
  },
};

module.exports = ScheduleModel;
