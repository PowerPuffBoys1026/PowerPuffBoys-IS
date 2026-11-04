const db = require('../db');

const SELECT_SLOT = `
  SELECT sc.*, s.code AS subject_code, s.title AS subject_title, s.color
    FROM schedule_slots sc
    JOIN subjects s ON s.id = sc.subject_id`;

const ScheduleModel = {
  findAllByUserId: async (userId, day) => {
    const params = [userId];
    let sql = `${SELECT_SLOT} WHERE s.user_id = $1`;

    if (day !== undefined && day !== '') {
      const dayNum = Number(day);
      sql += ` AND sc.day_of_week = $${params.length + 1}`;
      params.push(dayNum);
    }

    sql += ' ORDER BY sc.day_of_week, sc.start_time';
    const result = await db.query(sql, params);
    return result.rows;
  },

  findById: async (id) => {
    const result = await db.query(`${SELECT_SLOT} WHERE sc.id = $1`, [id]);
    return result.rows[0] || null;
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query(`${SELECT_SLOT} WHERE sc.id = $1 AND s.user_id = $2`, [id, userId]);
    return result.rows[0] || null;
  },

  create: async ({ subjectId, dayOfWeek, startTime, endTime, room, modality }) => {
    const result = await db.query(
      'INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time, room, modality) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id',
      [subjectId, dayOfWeek, startTime, endTime, room ?? null, modality ?? null],
    );
    return result.rows[0].id;
  },

  update: async (id, updates, current) => {
    await db.query(
      'UPDATE schedule_slots SET subject_id = $1, day_of_week = $2, start_time = $3, end_time = $4, room = $5, modality = $6 WHERE id = $7',
      [
        updates.subjectId ?? current.subject_id,
        updates.dayOfWeek ?? current.day_of_week,
        updates.startTime ?? current.start_time,
        updates.endTime ?? current.end_time,
        updates.room !== undefined ? updates.room : current.room,
        updates.modality !== undefined ? updates.modality : current.modality,
        id,
      ],
    );
  },

  delete: (id) => {
    return db.query('DELETE FROM schedule_slots WHERE id = $1', [id]);
  },

  subjectExistsAndOwned: async (subjectId, userId) => {
    const result = await db.query('SELECT id FROM subjects WHERE id = $1 AND user_id = $2', [subjectId, userId]);
    return result.rowCount > 0;
  },
};

module.exports = ScheduleModel;
