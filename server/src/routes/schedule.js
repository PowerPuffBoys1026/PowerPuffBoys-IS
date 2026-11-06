const express = require('express');
const { asyncHandler } = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const ScheduleController = require('../controllers/schedule.controller');

const router = express.Router();
router.use(requireAuth);

// GET /api/schedule?day=0..6
router.get('/', asyncHandler(ScheduleController.getAll));

// POST /api/schedule
router.post('/', asyncHandler(ScheduleController.create));

// PUT /api/schedule/:id
router.put('/:id', asyncHandler(ScheduleController.update));

// DELETE /api/schedule/:id
router.delete('/:id', asyncHandler(ScheduleController.delete));

module.exports = router;
