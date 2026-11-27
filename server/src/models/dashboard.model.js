const db = require('../db');
const { dateInTimeZone, dayOfWeekInTimeZone } = require('../utils/dates');

const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

const DashboardModel = {
  getToday: async (userId, date = new Date()) => {
    const dayOfWeek = dayOfWeekInTimeZone(date);
    const today = dateInTimeZone(date);

    // Migration 005 owns these queries so the API and database agree on
    // "today", due-soon and ordering rules. Aliases keep the existing view
    // contract unchanged.
    const classesResult = await db.query(
      `SELECT c.slot_id AS id, c.start_time, c.end_time, c.room, c.modality,
              c.subject_id, c.code, c.title, c.color
         FROM get_dashboard_classes($1, $2) c`,
      [userId, dayOfWeek],
    );

    const dueSoonResult = await db.query(
      `SELECT w.work_id AS id, w.title, w.work_type AS type, w.due_at,
              w.priority, w.status, w.subject_code, w.color
         FROM get_due_soon_works($1, $2, 7) w`,
      [userId, today],
    );

    return {
      date: today,
      dayName: DAY_NAMES[dayOfWeek],
      dayOfWeek,
      classes: classesResult.rows,
      dueSoon: dueSoonResult.rows,
    };
  },
};

module.exports = DashboardModel;
