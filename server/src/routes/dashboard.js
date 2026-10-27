const express = require('express');
const { requireAuth } = require('../middleware/auth');
const DashboardController = require('../controllers/dashboard.controller');

const router = express.Router();
router.use(requireAuth);

// GET /api/dashboard/today
router.get('/today', DashboardController.getToday);

module.exports = router;
