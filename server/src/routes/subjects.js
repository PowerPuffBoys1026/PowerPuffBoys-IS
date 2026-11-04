const express = require('express');
const { asyncHandler } = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const SubjectController = require('../controllers/subject.controller');

const router = express.Router();
router.use(requireAuth);

// GET /api/subjects
router.get('/', asyncHandler(SubjectController.getAll));

// POST /api/subjects
router.post('/', asyncHandler(SubjectController.create));

// GET /api/subjects/:id
router.get('/:id', asyncHandler(SubjectController.getOne));

// PUT /api/subjects/:id
router.put('/:id', asyncHandler(SubjectController.update));

// DELETE /api/subjects/:id
router.delete('/:id', asyncHandler(SubjectController.delete));

module.exports = router;
