const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const multer = require('multer');

const db = require('../db');
const config = require('../config');
const { HttpError } = require('../utils/errors');

fs.mkdirSync(config.uploadDir, { recursive: true });

const FILE_TYPES = {
  '.png': { mimeType: 'image/png' },
  '.jpg': { mimeType: 'image/jpeg' },
  '.jpeg': { mimeType: 'image/jpeg' },
  '.gif': { mimeType: 'image/gif' },
  '.webp': { mimeType: 'image/webp' },
  '.pdf': { mimeType: 'application/pdf' },
  '.doc': { mimeType: 'application/msword' },
  '.docx': { mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' },
  '.ppt': { mimeType: 'application/vnd.ms-powerpoint' },
  '.pptx': { mimeType: 'application/vnd.openxmlformats-officedocument.presentationml.presentation' },
  '.txt': { mimeType: 'text/plain' },
};

const storage = multer.diskStorage({
  destination: config.uploadDir,
  filename(req, file, callback) {
    const extension = path.extname(file.originalname.replaceAll('\\', '/')).toLowerCase();
    callback(null, `${crypto.randomUUID()}${extension}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 20 * 1024 * 1024, files: 1 },
  fileFilter(req, file, callback) {
    const extension = path.extname(file.originalname.replaceAll('\\', '/')).toLowerCase();
    const type = FILE_TYPES[extension];
    if (!type) return callback(new HttpError(415, 'Use an image, PDF, Word, PowerPoint, or text file.'));
    if (file.mimetype && file.mimetype !== type.mimeType && file.mimetype !== 'application/octet-stream') {
      return callback(new HttpError(415, 'The selected file type does not match its extension.'));
    }
    file.validatedMimeType = type.mimeType;
    return callback(null, true);
  },
});

function metadata(row) {
  return {
    id: row.id,
    resourceType: row.resource_type,
    resourceId: row.resource_id,
    originalName: row.original_name,
    mimeType: row.mime_type,
    sizeBytes: row.size_bytes,
    createdAt: row.created_at,
  };
}

function safeOriginalName(name) {
  return path.posix.basename(String(name).replaceAll('\\', '/'))
    .replace(/[\u0000-\u001f\u007f]/g, '')
    .trim()
    .slice(0, 180) || 'attachment';
}

async function addAttachment(userId, resourceType, resourceId, file) {
  if (!file) throw new HttpError(400, 'Choose a file to upload.');
  const result = await db.query('SELECT * FROM fn_attachment_add($1,$2,$3,$4,$5,$6,$7)', [
    userId,
    resourceType,
    resourceId,
    safeOriginalName(file.originalname),
    path.basename(file.filename),
    file.validatedMimeType,
    file.size,
  ]);
  return metadata(result.rows[0]);
}

async function listResource(userId, resourceType, resourceId) {
  const result = await db.query('SELECT * FROM fn_attachment_list_resource($1,$2,$3)', [userId, resourceType, resourceId]);
  return result.rows.map(metadata);
}

async function listAll(userId, resourceType) {
  const result = await db.query('SELECT * FROM fn_attachment_list_all($1,$2)', [userId, resourceType]);
  return result.rows.map(metadata);
}

async function getOwnedAttachment(userId, id) {
  const result = await db.query('SELECT * FROM fn_attachment_get_owned($1,$2)', [userId, id]);
  const row = result.rows[0];
  if (!row) throw new HttpError(404, 'Attachment not found');
  return row;
}

function filePath(row) {
  const filename = path.basename(row.stored_name);
  if (filename !== row.stored_name) throw new HttpError(404, 'Attachment not found');
  return path.join(config.uploadDir, filename);
}

function removeFile(row) {
  try {
    fs.unlinkSync(filePath(row));
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}

async function deleteAttachment(userId, id) {
  const row = await getOwnedAttachment(userId, id);
  await db.query('SELECT * FROM fn_attachment_delete($1,$2)', [userId, id]);
  removeFile(row);
}

async function removeForResource(userId, resourceType, resourceId) {
  const result = await db.query('SELECT * FROM fn_attachment_delete_for_resource($1,$2,$3)', [userId, resourceType, resourceId]);
  for (const row of result.rows) removeFile(row);
}

async function removeForRecycleItem(userId, itemType, payload) {
  if (itemType === 'task') await removeForResource(userId, 'work', payload.id);
  if (itemType === 'note') await removeForResource(userId, 'note', payload.id);
  if (itemType === 'subject') {
    for (const task of payload.tasks || []) await removeForResource(userId, 'work', task.id);
    for (const note of payload.notes || []) await removeForResource(userId, 'note', note.id);
  }
}

module.exports = {
  addAttachment,
  deleteAttachment,
  filePath,
  getOwnedAttachment,
  listAll,
  listResource,
  removeForRecycleItem,
  removeForResource,
  upload,
};
