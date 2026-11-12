const db = require('../db');
const { HttpError } = require('../utils/errors');
const attachments = require('./attachments');

function mapDbError(e) {
  const msg = e && e.message ? String(e.message) : '';
  if (msg.includes('NOT_FOUND:')) throw new HttpError(404, msg.split('NOT_FOUND:')[1] || 'Not found');
  if (msg.includes('BAD_REQUEST:')) throw new HttpError(400, msg.split('BAD_REQUEST:')[1] || 'Bad request');
  if (e && e.code === '23503') throw new HttpError(409, 'Restore the related course first, then restore this item.');
  throw e;
}

async function cleanupFiles(items) {
  for (const item of items || []) {
    try {
      const payload = typeof item.payload_json === 'string' ? JSON.parse(item.payload_json) : item.payload_json;
      await attachments.removeForRecycleItem(item.user_id, item.item_type, payload);
    } catch {}
  }
}

async function purgeExpired(userId = null) {
  const res = await db.query('SELECT * FROM fn_recycle_purge_expired($1)', [userId]);
  await cleanupFiles(res.rows);
}

async function trashRecord(userId, type, id) {
  try {
    await purgeExpired(userId);
    const res = await db.query('SELECT fn_recycle_trash($1,$2,$3) AS id', [userId, type, id]);
    return res.rows[0].id;
  } catch (e) {
    mapDbError(e);
  }
}

async function restoreRecord(userId, id) {
  try {
    await purgeExpired(userId);
    const res = await db.query('SELECT * FROM fn_recycle_restore($1,$2)', [userId, id]);
    const row = res.rows[0];
    if (!row) throw new HttpError(404, 'Recycle-bin item not found or expired');
    return { id: row.id, type: row.type, label: row.label };
  } catch (e) {
    mapDbError(e);
  }
}

async function listItems(userId) {
  await purgeExpired(userId);
  const res = await db.query('SELECT * FROM fn_recycle_list($1)', [userId]);
  return res.rows;
}

async function permanentlyDelete(userId, id) {
  await purgeExpired(userId);
  const got = await db.query('SELECT * FROM fn_recycle_get($1,$2)', [userId, id]);
  const item = got.rows[0];
  if (!item) throw new HttpError(404, 'Recycle-bin item not found or expired');
  await db.query('SELECT * FROM fn_recycle_delete($1,$2)', [userId, id]);
  try {
    const payload = typeof item.payload_json === 'string' ? JSON.parse(item.payload_json) : item.payload_json;
    await attachments.removeForRecycleItem(item.user_id, item.item_type, payload);
  } catch {}
}

module.exports = { listItems, permanentlyDelete, purgeExpired, restoreRecord, trashRecord };
