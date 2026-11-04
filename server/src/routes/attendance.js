const express = require('express');
const { asyncHandler } = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const AttendanceController = require('../controllers/attendance.controller');

const router = express.Router();
router.use(requireAuth);

// GET /api/attendance/summary  (declared before /:id)
router.get('/summary', asyncHandler(AttendanceController.getSummary));

// GET /api/attendance?subjectId=&from=&to=
router.get('/', asyncHandler(AttendanceController.getAll));

// POST /api/attendance
router.post('/', asyncHandler(AttendanceController.create));

// PUT /api/attendance/:id
router.put('/:id', asyncHandler(AttendanceController.update));

// DELETE /api/attendance/:id
router.delete('/:id', asyncHandler(AttendanceController.delete));

module.exports = router;
