const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const multer = require('multer');

const db = require('../db');
const config = require('../config');
const { HttpError } = require('../utils/errors');

const databaseName = path.basename(config.dbFile, path.extname(config.dbFile));
const uploadDirectory = path.join(path.dirname(config.dbFile), `${databaseName}-uploads`);
fs.mkdirSync(uploadDirectory, { recursive: true });

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
  destination: uploadDirectory,
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

function addAttachment(userId, resourceType, resourceId, file) {
  if (!file) throw new HttpError(400, 'Choose a file to upload.');
  const result = db.prepare(
    `INSERT INTO attachments (user_id, resource_type, resource_id, original_name, stored_name, mime_type, size_bytes)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    userId,
    resourceType,
    resourceId,
    safeOriginalName(file.originalname),
    path.basename(file.filename),
    file.validatedMimeType,
    file.size,
  );
  return metadata(db.prepare('SELECT * FROM attachments WHERE id = ?').get(result.lastInsertRowid));
}

function listResource(userId, resourceType, resourceId) {
  const rows = db.prepare(
    `SELECT * FROM attachments
      WHERE user_id = ? AND resource_type = ? AND resource_id = ?
      ORDER BY created_at, id`,
  ).all(userId, resourceType, resourceId);
  return rows.map(metadata);
}

function listAll(userId, resourceType) {
  const table = resourceType === 'work' ? 'school_works' : 'subject_notes';
  const rows = db.prepare(
    `SELECT attachment.* FROM attachments attachment
       JOIN ${table} resource ON resource.id = attachment.resource_id AND resource.user_id = attachment.user_id
      WHERE attachment.user_id = ? AND attachment.resource_type = ?
      ORDER BY attachment.created_at, attachment.id`,
  ).all(userId, resourceType);
  return rows.map(metadata);
}

function getOwnedAttachment(userId, id) {
  const row = db.prepare('SELECT * FROM attachments WHERE id = ? AND user_id = ?').get(id, userId);
  if (!row) throw new HttpError(404, 'Attachment not found');

  const table = row.resource_type === 'work' ? 'school_works' : 'subject_notes';
  const resource = db.prepare(`SELECT id FROM ${table} WHERE id = ? AND user_id = ?`).get(row.resource_id, userId);
  if (!resource) throw new HttpError(404, 'Attachment not found');
  return row;
}

function filePath(row) {
  const filename = path.basename(row.stored_name);
  if (filename !== row.stored_name) throw new HttpError(404, 'Attachment not found');
  return path.join(uploadDirectory, filename);
}

function removeFile(row) {
  try {
    fs.unlinkSync(filePath(row));
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}

function deleteAttachment(userId, id) {
  const row = getOwnedAttachment(userId, id);
  db.prepare('DELETE FROM attachments WHERE id = ? AND user_id = ?').run(id, userId);
  removeFile(row);
}

function removeForResource(userId, resourceType, resourceId) {
  const rows = db.prepare(
    'SELECT * FROM attachments WHERE user_id = ? AND resource_type = ? AND resource_id = ?',
  ).all(userId, resourceType, resourceId);
  db.prepare(
    'DELETE FROM attachments WHERE user_id = ? AND resource_type = ? AND resource_id = ?',
  ).run(userId, resourceType, resourceId);
  for (const row of rows) removeFile(row);
}

function removeForRecycleItem(userId, itemType, payload) {
  if (itemType === 'task') removeForResource(userId, 'work', payload.id);
  if (itemType === 'note') removeForResource(userId, 'note', payload.id);
  if (itemType === 'subject') {
    for (const task of payload.tasks || []) removeForResource(userId, 'work', task.id);
    for (const note of payload.notes || []) removeForResource(userId, 'note', note.id);
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