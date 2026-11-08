const express = require('express');
const fs = require('node:fs');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { HttpError } = require('../utils/errors');
const { asyncHandler } = require('../utils/asyncHandler');
const attachments = require('../services/attachments');
const { parseId } = require('../utils/parse');

const router = express.Router();
router.use(requireAuth);

const RESOURCE_TYPES = {
  works: { type: 'work', table: 'school_works' },
  notes: { type: 'note', table: 'notes' },
};

async function ownedResource(req, res, next) {
  try {
    const config = RESOURCE_TYPES[req.params.resourceType];
    const id = parseId(req.params.resourceId, 'resourceId');
    if (!config) return next(new HttpError(404, 'Attachment collection not found'));
    const resource = await db.query(`SELECT id FROM ${config.table} WHERE id = $1 AND user_id = $2`, [id, req.userId]);
    if (!resource.rows[0]) return next(new HttpError(404, 'Task or note not found'));
    const count = await db.query(
      'SELECT COUNT(*)::int AS count FROM attachments WHERE user_id = $1 AND resource_type = $2 AND resource_id = $3',
      [req.userId, config.type, id],
    );
    if (req.method === 'POST' && count.rows[0].count >= 10) return next(new HttpError(409, 'A record can have up to 10 attachments.'));
    req.attachmentResource = { ...config, id };
    return next();
  } catch (e) { return next(e); }
}

function parseUpload(req, res, next) {
  attachments.upload.single('file')(req, res, (error) => {
    if (!error) return next();
    const status = error.status || 400;
    const message = (() => {
      if (error.status) return error.message;
      if (error.code === 'LIMIT_FILE_SIZE') return 'Each attachment must be 20 MB or smaller.';
      if (error.code === 'LIMIT_UNEXPECTED_FILE') return 'Upload one file at a time.';
      return error.message || 'Could not read the uploaded file.';
    })();
    if (req.file?.path) fs.promises.unlink(req.file.path).catch(() => {});
    return res.status(status).json({ error: { message } });
  });
}

router.get('/:id/download', asyncHandler(async (req, res, next) => {
  const id = parseId(req.params.id, 'attachmentId');
  const row = await attachments.getOwnedAttachment(req.userId, id);
  const fp = attachments.filePath(row);
  res.setHeader('Content-Type', row.mime_type);
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.download(fp, row.original_name, (err) => { if (err && !res.headersSent) next(err); });
}));

router.get('/:resourceType', asyncHandler(async (req, res) => {
  const config = RESOURCE_TYPES[req.params.resourceType];
  if (!config) throw new HttpError(404, 'Attachment collection not found');
  res.json({ data: await attachments.listAll(req.userId, config.type) });
}));

router.get('/:resourceType/:resourceId', ownedResource, asyncHandler(async (req, res) => {
  res.json({ data: await attachments.listResource(req.userId, req.attachmentResource.type, req.attachmentResource.id) });
}));

router.post('/:resourceType/:resourceId', ownedResource, parseUpload, asyncHandler(async (req, res, next) => {
  try {
    const attachment = await attachments.addAttachment(req.userId, req.attachmentResource.type, req.attachmentResource.id, req.file);
    return res.status(201).json({ data: attachment });
  } catch (error) {
    if (req.file?.path) fs.promises.unlink(req.file.path).catch(() => {});
    return next(error);
  }
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  const id = parseId(req.params.id, 'attachmentId');
  await attachments.deleteAttachment(req.userId, id);
  res.status(204).end();
}));

module.exports = router;
