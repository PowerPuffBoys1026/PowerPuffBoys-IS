const express = require('express');
const { asyncHandler } = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');
const NoteController = require('../controllers/note.controller');

const router = express.Router();
router.use(requireAuth);

router.get('/', asyncHandler(NoteController.getAll));
router.post('/', asyncHandler(NoteController.create));
router.get('/:id', asyncHandler(NoteController.getOne));
router.put('/:id', asyncHandler(NoteController.update));
router.patch('/:id/pin', asyncHandler(NoteController.togglePin));
router.delete('/:id', asyncHandler(NoteController.delete));

module.exports = router;
