const DashboardModel = require('../models/dashboard.model');
const { attendanceSummary } = require('../services/attendance');
const { asyncHandler } = require('../utils/async-handler');
const { toDashboard } = require('../views/dashboard.view');

const DashboardController = {
  getToday: asyncHandler(async (req, res) => {
    const today = await DashboardModel.getToday(req.userId, new Date());
    const attendanceWarnings = (await attendanceSummary(req.userId)).filter((s) => s.warning);

    res.json({
      data: toDashboard({
        date: today.date,
        dayName: today.dayName,
        classes: today.classes,
        dueSoon: today.dueSoon,
        attendanceWarnings,
      }),
    });
  }),
};

module.exports = DashboardController;
