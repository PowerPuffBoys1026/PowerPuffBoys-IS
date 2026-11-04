const express = require('express');
const { asyncHandler } = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const DashboardController = require('../controllers/dashboard.controller');

const router = express.Router();
router.use(requireAuth);

// GET /api/dashboard/today
router.get('/today', asyncHandler(DashboardController.getToday));

module.exports = router;
