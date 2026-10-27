const express = require('express');
const { requireAuth } = require('../middleware/auth');
const SubjectController = require('../controllers/subject.controller');

const router = express.Router();
router.use(requireAuth);

// GET /api/subjects
router.get('/', SubjectController.getAll);

// POST /api/subjects
router.post('/', SubjectController.create);

// GET /api/subjects/:id
router.get('/:id', SubjectController.getOne);

// PUT /api/subjects/:id
router.put('/:id', SubjectController.update);

// DELETE /api/subjects/:id
router.delete('/:id', SubjectController.delete);

module.exports = router;
