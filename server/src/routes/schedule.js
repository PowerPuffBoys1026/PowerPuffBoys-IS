const express = require('express');
const { requireAuth } = require('../middleware/auth');
const ScheduleController = require('../controllers/schedule.controller');

const router = express.Router();
router.use(requireAuth);

// GET /api/schedule?day=0..6
router.get('/', ScheduleController.getAll);

// POST /api/schedule
router.post('/', ScheduleController.create);

// PUT /api/schedule/:id
router.put('/:id', ScheduleController.update);

// DELETE /api/schedule/:id
router.delete('/:id', ScheduleController.delete);

module.exports = router;
