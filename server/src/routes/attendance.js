const express = require('express');
const { requireAuth } = require('../middleware/auth');
const AttendanceController = require('../controllers/attendance.controller');

const router = express.Router();
router.use(requireAuth);

// GET /api/attendance/summary  (declared before /:id)
router.get('/summary', AttendanceController.getSummary);

// GET /api/attendance?subjectId=&from=&to=
router.get('/', AttendanceController.getAll);

// POST /api/attendance
router.post('/', AttendanceController.create);

// PUT /api/attendance/:id
router.put('/:id', AttendanceController.update);

// DELETE /api/attendance/:id
router.delete('/:id', AttendanceController.delete);

module.exports = router;
