const DashboardModel = require('../models/dashboard.model');
const { attendanceSummary } = require('../services/attendance');
const { toDashboard } = require('../views/dashboard.view');

const DashboardController = {
  getToday: async (req, res) => {
    const today = await DashboardModel.getToday(req.userId, new Date());
    const summary = await attendanceSummary(req.userId);
    const attendanceWarnings = summary.filter((s) => s.warning);

    res.json({
      data: toDashboard({
        date: today.date,
        dayName: today.dayName,
        classes: today.classes,
        dueSoon: today.dueSoon,
        attendanceWarnings,
      }),
    });
  },
};

module.exports = DashboardController;
