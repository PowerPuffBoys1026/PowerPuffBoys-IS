const express = require('express');
const { requireAuth } = require('../middleware/auth');
const NoteController = require('../controllers/note.controller');

const router = express.Router();
router.use(requireAuth);

router.get('/', NoteController.getAll);
router.post('/', NoteController.create);
router.get('/:id', NoteController.getOne);
router.put('/:id', NoteController.update);
router.patch('/:id/pin', NoteController.togglePin);
router.delete('/:id', NoteController.delete);

module.exports = router;
