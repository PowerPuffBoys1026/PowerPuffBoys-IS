const db = require('../db');
const { dateInTimeZone, dayOfWeekInTimeZone } = require('../utils/dates');

const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

const DashboardModel = {
  getToday: async (userId, date = new Date()) => {
    const dayOfWeek = dayOfWeekInTimeZone(date);
    const today = dateInTimeZone(date);

    const classesResult = await db.query('SELECT * FROM fn_dashboard_classes($1, $2)', [userId, dayOfWeek]);
    const dueSoonResult = await db.query('SELECT * FROM fn_dashboard_due_soon($1, $2)', [userId, today]);

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
