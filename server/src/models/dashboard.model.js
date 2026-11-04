const db = require('../db');

const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function localDateString(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

const DashboardModel = {
  getToday: async (userId, date = new Date()) => {
    const dayOfWeek = date.getDay();
    const today = localDateString(date);

    const classesResult = await db.query(
      `SELECT sc.id, sc.start_time, sc.end_time, sc.room, sc.modality,
              s.id AS subject_id, s.code, s.title, s.color
         FROM schedule_slots sc
         JOIN subjects s ON s.id = sc.subject_id
        WHERE s.user_id = $1 AND sc.day_of_week = $2
        ORDER BY sc.start_time`,
      [userId, dayOfWeek],
    );

    const dueSoonResult = await db.query(
      `SELECT w.id, w.title, w.type, w.due_at, w.priority, w.status,
              s.code AS subject_code, s.color
         FROM school_works w
         LEFT JOIN subjects s ON s.id = w.subject_id
        WHERE w.user_id = $1
          AND w.status != 'done'
          AND w.due_at IS NOT NULL
          AND DATE(w.due_at) <= DATE($2) + INTERVAL '7 days'
        ORDER BY w.due_at`,
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
