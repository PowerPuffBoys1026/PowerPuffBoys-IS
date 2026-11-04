const express = require('express');
const { asyncHandler } = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const WorkController = require('../controllers/work.controller');

const router = express.Router();
router.use(requireAuth);

// GET /api/works?status=&subjectId=&dueBefore=
router.get('/', asyncHandler(WorkController.getAll));

// POST /api/works
router.post('/', asyncHandler(WorkController.create));

// GET /api/works/:id
router.get('/:id', asyncHandler(WorkController.getOne));

// PUT /api/works/:id
router.put('/:id', asyncHandler(WorkController.update));

// PATCH /api/works/:id/status
router.patch('/:id/status', asyncHandler(WorkController.updateStatus));

// DELETE /api/works/:id
router.delete('/:id', asyncHandler(WorkController.delete));

module.exports = router;
