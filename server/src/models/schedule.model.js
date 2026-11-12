const db = require('../db');

const ScheduleModel = {
  findAllByUserId: async (userId, { day, limit, offset } = {}) => {
    const dayVal = day === undefined || day === '' ? null : Number(day);
    const result = await db.query('SELECT * FROM fn_schedule_list($1, $2, $3, $4)', [userId, dayVal, limit ?? null, offset ?? null]);
    return result.rows;
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query('SELECT * FROM fn_schedule_get($1, $2)', [id, userId]);
    return result.rows[0] || null;
  },

  create: async ({ subjectId, dayOfWeek, startTime, endTime, room, building, modality, weekPattern }) => {
    const result = await db.query(
      'SELECT * FROM fn_schedule_create($1, $2, $3, $4, $5, $6, $7, $8)',
      [subjectId, dayOfWeek, startTime, endTime, room ?? null, building ?? null, modality ?? null, weekPattern ?? 'every'],
    );
    return result.rows[0];
  },

  update: async (id, updates, current, userId) => {
    const result = await db.query(
      'SELECT * FROM fn_schedule_update($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)',
      [
        id,
        userId,
        updates.subjectId ?? current.subject_id,
        updates.dayOfWeek ?? current.day_of_week,
        updates.startTime ?? current.start_time,
        updates.endTime ?? current.end_time,
        updates.room !== undefined ? updates.room : current.room,
        updates.building !== undefined ? updates.building : current.building,
        updates.modality !== undefined ? updates.modality : current.modality,
        updates.weekPattern ?? current.week_pattern ?? 'every',
      ],
    );
    return result.rows[0] || null;
  },

  delete: (id, userId) => db.query('SELECT fn_schedule_delete($1, $2) AS count', [id, userId]),

  subjectExistsAndOwned: async (subjectId, userId) => {
    const result = await db.query('SELECT fn_subject_owned($1, $2) AS exists', [subjectId, userId]);
    return Boolean(result.rows[0]?.exists);
  },
};

module.exports = ScheduleModel;
