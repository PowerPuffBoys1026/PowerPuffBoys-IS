const express = require('express');

const { requireAuth } = require('../middleware/auth');
const { HttpError } = require('../utils/errors');
const recycleBin = require('../services/recycle_bin');

const router = express.Router();
router.use(requireAuth);

router.get('/', (req, res) => {
  res.json({ data: recycleBin.listItems(req.userId) });
});

router.post('/:id/restore', (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) throw new HttpError(400, 'Recycle-bin item ID is invalid');
  res.json({ data: recycleBin.restoreRecord(req.userId, id) });
});

router.delete('/:id', (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) throw new HttpError(400, 'Recycle-bin item ID is invalid');
  recycleBin.permanentlyDelete(req.userId, id);
  res.status(204).end();
});

module.exports = router;