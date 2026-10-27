const express = require('express');
const fs = require('node:fs');

const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { HttpError } = require('../utils/errors');
const attachments = require('../services/attachments');

const router = express.Router();
router.use(requireAuth);

const RESOURCE_TYPES = {
  works: { type: 'work', table: 'school_works' },
  notes: { type: 'note', table: 'subject_notes' },
};

function ownedResource(req, res, next) {
  const config = RESOURCE_TYPES[req.params.resourceType];
  const id = Number(req.params.resourceId);
  if (!config) return next(new HttpError(404, 'Attachment collection not found'));
  if (!Number.isSafeInteger(id) || id <= 0) return next(new HttpError(400, 'Resource ID is invalid'));

  const resource = db.prepare(`SELECT id FROM ${config.table} WHERE id = ? AND user_id = ?`).get(id, req.userId);
  if (!resource) return next(new HttpError(404, 'Task or note not found'));

  const count = db.prepare(
    'SELECT COUNT(*) AS count FROM attachments WHERE user_id = ? AND resource_type = ? AND resource_id = ?',
  ).get(req.userId, config.type, id).count;
  if (req.method === 'POST' && count >= 10) return next(new HttpError(409, 'A record can have up to 10 attachments.'));

  req.attachmentResource = { ...config, id };
  return next();
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

    if (req.file?.path) {
      fs.promises.unlink(req.file.path).catch(() => {});
    }

    return res.status(status).json({ error: { message } });
  });
}

router.get('/:id/download', (req, res, next) => {
  const id = Number(req.params.id);
  if (!Number.isSafeInteger(id) || id <= 0) return next(new HttpError(400, 'Attachment ID is invalid'));

  try {
    const row = attachments.getOwnedAttachment(req.userId, id);
    return res.download(attachments.filePath(row), row.original_name, {
      headers: { 'Content-Type': row.mime_type, 'X-Content-Type-Options': 'nosniff' },
    }, (error) => {
      if (!error) return;
      if (res.headersSent) return res.destroy(error);
      return next(error);
    });
  } catch (error) {
    return next(error);
  }
});

router.get('/:resourceType', (req, res, next) => {
  const config = RESOURCE_TYPES[req.params.resourceType];
  if (!config) return next(new HttpError(404, 'Attachment collection not found'));
  res.json({ data: attachments.listAll(req.userId, config.type) });
});

router.get('/:resourceType/:resourceId', ownedResource, (req, res) => {
  res.json({ data: attachments.listResource(req.userId, req.attachmentResource.type, req.attachmentResource.id) });
});

router.post('/:resourceType/:resourceId', ownedResource, parseUpload, (req, res, next) => {
  try {
    const attachment = attachments.addAttachment(
      req.userId,
      req.attachmentResource.type,
      req.attachmentResource.id,
      req.file,
    );
    return res.status(201).json({ data: attachment });
  } catch (error) {
    if (req.file?.path) require('node:fs').promises.unlink(req.file.path).catch(() => {});
    return next(error);
  }
});

router.delete('/:id', (req, res, next) => {
  const id = Number(req.params.id);
  if (!Number.isSafeInteger(id) || id <= 0) return next(new HttpError(400, 'Attachment ID is invalid'));
  try {
    attachments.deleteAttachment(req.userId, id);
    return res.status(204).end();
  } catch (error) {
    return next(error);
  }
});

module.exports = router;