const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { HttpError } = require('../utils/errors');
const { asyncHandler } = require('../utils/asyncHandler');
const recycleBin = require('../services/recycle_bin');
const { parseId } = require('../utils/parse');

const router = express.Router();
router.use(requireAuth);

router.get('/', asyncHandler(async (req, res) => {
  res.json({ data: await recycleBin.listItems(req.userId) });
}));

router.post('/:id/restore', asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  res.json({ data: await recycleBin.restoreRecord(req.userId, id) });
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  await recycleBin.permanentlyDelete(req.userId, id);
  res.status(204).end();
}));

module.exports = router;
