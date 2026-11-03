const { query } = require('../db');

const SELECT_SLOT = `
  SELECT sc.id,
         sc.subject_id,
         sc.day_of_week,
         to_char(sc.start_time, 'HH24:MI') AS start_time,
         to_char(sc.end_time, 'HH24:MI') AS end_time,
         sc.room,
         sc.modality,
         s.code AS subject_code,
         s.title AS subject_title,
         s.color
    FROM schedule_slots sc
    JOIN subjects s ON s.id = sc.subject_id`;

const ScheduleModel = {
  findAllByUserId: async (userId, day) => {
    const params = [userId];
    let sql = `${SELECT_SLOT} WHERE s.user_id = $1`;

    if (day !== undefined && day !== '') {
      const dayNum = Number(day);
      sql += ' AND sc.day_of_week = $2';
      params.push(dayNum);
    }

    sql += ' ORDER BY sc.day_of_week, sc.start_time';
    const { rows } = await query(sql, params);
    return rows;
  },

  findById: async (id) => {
    const { rows } = await query(`${SELECT_SLOT} WHERE sc.id = $1`, [id]);
    return rows[0];
  },

  findByIdAndUserId: async (id, userId) => {
    const { rows } = await query(
      `${SELECT_SLOT} WHERE sc.id = $1 AND s.user_id = $2`,
      [id, userId],
    );
    return rows[0];
  },

  create: async ({ subjectId, dayOfWeek, startTime, endTime, room, modality }) => {
    const { rows } = await query(
      `INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time, room, modality)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id`,
      [subjectId, dayOfWeek, startTime, endTime, room ?? null, modality ?? null],
    );
    return rows[0].id;
  },

  update: async (id, updates, current) => {
    await query(
      `UPDATE schedule_slots
          SET subject_id = $1, day_of_week = $2, start_time = $3,
              end_time = $4, room = $5, modality = $6
        WHERE id = $7`,
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

  delete: async (id) => {
    const { rowCount } = await query('DELETE FROM schedule_slots WHERE id = $1', [id]);
    return rowCount;
  },

  subjectExistsAndOwned: async (subjectId, userId) => {
    const { rowCount } = await query(
      'SELECT 1 FROM subjects WHERE id = $1 AND user_id = $2',
      [subjectId, userId],
    );
    return rowCount > 0;
  },
};

module.exports = ScheduleModel;
