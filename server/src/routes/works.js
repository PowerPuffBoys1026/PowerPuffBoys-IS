const express = require('express');
const { requireAuth } = require('../middleware/auth');
const WorkController = require('../controllers/work.controller');

const router = express.Router();
router.use(requireAuth);

// GET /api/works?status=&subjectId=&dueBefore=
router.get('/', WorkController.getAll);

// POST /api/works
router.post('/', WorkController.create);

// GET /api/works/:id
router.get('/:id', WorkController.getOne);

// PUT /api/works/:id
router.put('/:id', WorkController.update);

// PATCH /api/works/:id/status
router.patch('/:id/status', WorkController.updateStatus);

// DELETE /api/works/:id
router.delete('/:id', WorkController.delete);

module.exports = router;
