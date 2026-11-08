const db = require('../db');

const SELECT_SLOT = `
  SELECT sc.*, s.code AS subject_code, s.title AS subject_title, s.color
    FROM schedule_slots sc
    JOIN subjects s ON s.id = sc.subject_id`;

const ScheduleModel = {
  findAllByUserId: async (userId, { day, limit, offset } = {}) => {
    const params = [userId];
    let sql = `${SELECT_SLOT} WHERE s.user_id = $1`;

    if (day !== undefined && day !== '') {
      sql += ` AND sc.day_of_week = $${params.length + 1}`;
      params.push(day);
    }

    sql += ' ORDER BY sc.day_of_week, sc.start_time';

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

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query(`${SELECT_SLOT} WHERE sc.id = $1 AND s.user_id = $2`, [id, userId]);
    return result.rows[0] || null;
  },

  create: async ({ subjectId, dayOfWeek, startTime, endTime, room, building, modality, weekPattern }) => {
    const result = await db.query(
      `WITH inserted AS (
         INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time, room, building, modality, week_pattern)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *
       )
       SELECT i.*, s.code AS subject_code, s.title AS subject_title, s.color
         FROM inserted i
         JOIN subjects s ON s.id = i.subject_id`,
      [subjectId, dayOfWeek, startTime, endTime, room ?? null, building ?? null, modality ?? null, weekPattern ?? 'every'],
    );
    return result.rows[0];
  },

  /** Update a slot owned by `userId`; returns the joined row or null. */
  update: async (id, updates, current, userId) => {
    const result = await db.query(
      `WITH updated AS (
         UPDATE schedule_slots sc
            SET subject_id = $1, day_of_week = $2, start_time = $3, end_time = $4,
                room = $5, building = $6, modality = $7, week_pattern = $8
           FROM subjects s
          WHERE sc.id = $9 AND sc.subject_id = s.id AND s.user_id = $10
          RETURNING sc.*
       )
       SELECT u.*, s.code AS subject_code, s.title AS subject_title, s.color
         FROM updated u
         JOIN subjects s ON s.id = u.subject_id`,
      [
        updates.subjectId ?? current.subject_id,
        updates.dayOfWeek ?? current.day_of_week,
        updates.startTime ?? current.start_time,
        updates.endTime ?? current.end_time,
        updates.room !== undefined ? updates.room : current.room,
        updates.building !== undefined ? updates.building : current.building,
        updates.modality !== undefined ? updates.modality : current.modality,
        updates.weekPattern ?? current.week_pattern ?? 'every',
        id,
        userId,
      ],
    );
    return result.rows[0] || null;
  },

  delete: (id, userId) => {
    return db.query(
      `DELETE FROM schedule_slots sc
        USING subjects s
        WHERE sc.id = $1 AND sc.subject_id = s.id AND s.user_id = $2`,
      [id, userId],
    );
  },

  subjectExistsAndOwned: async (subjectId, userId) => {
    const result = await db.query('SELECT id FROM subjects WHERE id = $1 AND user_id = $2', [subjectId, userId]);
    return result.rowCount > 0;
  },
};

module.exports = ScheduleModel;
