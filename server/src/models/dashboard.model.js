const db = require('../db');

const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function localDateString(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

const DashboardModel = {
  getToday: (userId, date = new Date()) => {
    const dayOfWeek = date.getDay();
    const today = localDateString(date);

    const classes = db
      .prepare(
        `SELECT sc.id, sc.start_time, sc.end_time, sc.room, sc.modality,
                s.id AS subject_id, s.code, s.title, s.color
           FROM schedule_slots sc
           JOIN subjects s ON s.id = sc.subject_id
          WHERE s.user_id = ? AND sc.day_of_week = ?
          ORDER BY sc.start_time`,
      )
      .all(userId, dayOfWeek);

    const dueSoon = db
      .prepare(
        `SELECT w.id, w.title, w.type, w.due_at, w.priority, w.status,
                s.code AS subject_code, s.color
           FROM school_works w
           LEFT JOIN subjects s ON s.id = w.subject_id
          WHERE w.user_id = ?
            AND w.status != 'done'
            AND w.due_at IS NOT NULL
            AND date(w.due_at) <= date(?, '+7 days')
          ORDER BY w.due_at`,
      )
      .all(userId, today);

    return {
      date: today,
      dayName: DAY_NAMES[dayOfWeek],
      dayOfWeek,
      classes,
      dueSoon,
    };
  },
};

module.exports = DashboardModel;
