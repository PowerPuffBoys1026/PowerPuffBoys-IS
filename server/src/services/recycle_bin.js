const db = require('../db');
const { HttpError } = require('../utils/errors');
const attachments = require('./attachments');

const ALLOWED_TABLES = new Set([
  'subjects', 'schedule_slots', 'attendance_records', 'school_works', 'study_sessions', 'subject_grades', 'notes',
]);

function qv(row, col) { return row[col]; }

async function purgeExpired(client) {
  const exec = client || db;
  const expired = await exec.query("SELECT * FROM recycle_bin WHERE expires_at <= NOW()");
  for (const item of expired.rows) {
    try {
      const payload = typeof item.payload_json === 'string' ? JSON.parse(item.payload_json) : item.payload_json;
      await attachments.removeForRecycleItem(item.user_id, item.item_type, payload);
    } catch {}
  }
  await exec.query("DELETE FROM recycle_bin WHERE expires_at <= NOW()");
}

async function saveToBin(client, userId, type, label, payload) {
  const res = await client.query(
    `INSERT INTO recycle_bin (user_id, item_type, label, payload_json, deleted_at, expires_at)
     VALUES ($1, $2, $3, $4::jsonb, NOW(), NOW() + INTERVAL '30 days') RETURNING id`,
    [userId, type, label, JSON.stringify(payload)],
  );
  return res.rows[0].id;
}

async function getOwned(client, table, id, userId, ownerCol = 'user_id') {
  if (!ALLOWED_TABLES.has(table)) return null;
  const res = await client.query(`SELECT * FROM ${table} WHERE id = $1 AND ${ownerCol} = $2`, [id, userId]);
  return res.rows[0] || null;
}

async function trashRecord(userId, type, id) {
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    await purgeExpired(client);

    let binId;
    if (type === 'subject') {
      const subject = await getOwned(client, 'subjects', id, userId);
      if (!subject) throw new HttpError(404, 'Subject not found');
      const schedule = (await client.query('SELECT * FROM schedule_slots WHERE subject_id = $1', [id])).rows;
      const attendance = (await client.query('SELECT * FROM attendance_records WHERE subject_id = $1', [id])).rows;
      const grades = (await client.query('SELECT * FROM subject_grades WHERE subject_id = $1 AND user_id = $2', [id, userId])).rows;
      const tasks = (await client.query('SELECT * FROM school_works WHERE subject_id = $1 AND user_id = $2', [id, userId])).rows;
      const sessions = (await client.query('SELECT * FROM study_sessions WHERE subject_id = $1 AND user_id = $2', [id, userId])).rows;
      const notes = (await client.query('SELECT * FROM notes WHERE subject_id = $1 AND user_id = $2', [id, userId])).rows;
      const payload = { subject, schedule, attendance, grades, tasks, sessions, notes };
      binId = await saveToBin(client, userId, type, `${subject.code} — ${subject.title}`, payload);
      await client.query('DELETE FROM school_works WHERE subject_id = $1 AND user_id = $2', [id, userId]);
      await client.query('DELETE FROM study_sessions WHERE subject_id = $1 AND user_id = $2', [id, userId]);
      await client.query('DELETE FROM notes WHERE subject_id = $1 AND user_id = $2', [id, userId]);
      await client.query('DELETE FROM subjects WHERE id = $1 AND user_id = $2', [id, userId]);
    } else if (type === 'note') {
      const row = await getOwned(client, 'notes', id, userId);
      if (!row) throw new HttpError(404, 'Item not found');
      binId = await saveToBin(client, userId, type, row.title || 'Note', row);
      await client.query('DELETE FROM notes WHERE id = $1 AND user_id = $2', [id, userId]);
    } else if (type === 'task') {
      const row = await getOwned(client, 'school_works', id, userId);
      if (!row) throw new HttpError(404, 'Item not found');
      binId = await saveToBin(client, userId, type, row.title || 'Task', row);
      await client.query('DELETE FROM school_works WHERE id = $1 AND user_id = $2', [id, userId]);
    } else if (type === 'session') {
      const row = await getOwned(client, 'study_sessions', id, userId);
      if (!row) throw new HttpError(404, 'Item not found');
      binId = await saveToBin(client, userId, type, `Study session (${row.duration_minutes} min)`, row);
      await client.query('DELETE FROM study_sessions WHERE id = $1 AND user_id = $2', [id, userId]);
    } else if (type === 'grade') {
      const row = await getOwned(client, 'subject_grades', id, userId);
      if (!row) throw new HttpError(404, 'Item not found');
      binId = await saveToBin(client, userId, type, row.component_name || 'Grade', row);
      await client.query('DELETE FROM subject_grades WHERE id = $1 AND user_id = $2', [id, userId]);
    } else if (type === 'schedule') {
      const res = await client.query(
        `SELECT slot.* FROM schedule_slots slot JOIN subjects subject ON subject.id = slot.subject_id WHERE slot.id = $1 AND subject.user_id = $2`,
        [id, userId],
      );
      const row = res.rows[0];
      if (!row) throw new HttpError(404, 'Item not found');
      const sub = await client.query('SELECT code FROM subjects WHERE id = $1', [row.subject_id]);
      binId = await saveToBin(client, userId, type, `${sub.rows[0]?.code || 'Course'} timetable class`, row);
      await client.query('DELETE FROM schedule_slots WHERE id = $1', [id]);
    } else if (type === 'attendance') {
      const res = await client.query(
        `SELECT record.* FROM attendance_records record JOIN subjects subject ON subject.id = record.subject_id WHERE record.id = $1 AND subject.user_id = $2`,
        [id, userId],
      );
      const row = res.rows[0];
      if (!row) throw new HttpError(404, 'Item not found');
      binId = await saveToBin(client, userId, type, `${row.date} attendance (${row.status})`, row);
      await client.query('DELETE FROM attendance_records WHERE id = $1', [id]);
    } else {
      throw new HttpError(400, 'Unsupported recycle-bin item type');
    }

    await client.query('COMMIT');
    return binId;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

async function insertSnapshot(client, table, row) {
  if (!ALLOWED_TABLES.has(table)) throw new HttpError(400, 'Unsupported restore target');
  const columns = Object.keys(row);
  const values = columns.map((c) => row[c]);
  const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');
  await client.query(`INSERT INTO ${table} (${columns.map((c)=>`"${c}"`).join(', ')}) VALUES (${placeholders}) ON CONFLICT (id) DO NOTHING`, values);
  // fix sequence
  await client.query(`SELECT setval(pg_get_serial_sequence($1, 'id'), COALESCE((SELECT MAX(id) FROM ${table}), 1))`, [table]).catch(()=>{});
}

async function restoreRecord(userId, id) {
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    await purgeExpired(client);
    const itemRes = await client.query('SELECT * FROM recycle_bin WHERE id = $1 AND user_id = $2', [id, userId]);
    const item = itemRes.rows[0];
    if (!item) throw new HttpError(404, 'Recycle-bin item not found or expired');
    const payload = typeof item.payload_json === 'string' ? JSON.parse(item.payload_json) : item.payload_json;

    if (item.item_type === 'subject') {
      await insertSnapshot(client, 'subjects', payload.subject);
      for (const row of payload.schedule || []) await insertSnapshot(client, 'schedule_slots', row);
      for (const row of payload.attendance || []) {
        if (row.slot_id !== null && row.slot_id !== undefined) {
          const slot = await client.query('SELECT id FROM schedule_slots WHERE id = $1', [row.slot_id]);
          if (!slot.rows[0]) row.slot_id = null;
        }
        await insertSnapshot(client, 'attendance_records', row);
      }
      for (const row of payload.grades || []) await insertSnapshot(client, 'subject_grades', row);
      for (const row of payload.tasks || []) await insertSnapshot(client, 'school_works', row);
      for (const row of payload.sessions || []) await insertSnapshot(client, 'study_sessions', row);
      for (const row of payload.notes || []) await insertSnapshot(client, 'notes', row);
    } else {
      const map = { note:'notes', task:'school_works', session:'study_sessions', grade:'subject_grades', schedule:'schedule_slots', attendance:'attendance_records' };
      const table = map[item.item_type];
      if (!table) throw new HttpError(400, 'Unsupported recycle-bin item type');
      if (item.item_type === 'attendance' && payload.slot_id != null) {
        const slot = await client.query('SELECT id FROM schedule_slots WHERE id = $1', [payload.slot_id]);
        if (!slot.rows[0]) payload.slot_id = null;
      }
      await insertSnapshot(client, table, payload);
    }

    await client.query('DELETE FROM recycle_bin WHERE id = $1', [id]);
    await client.query('COMMIT');
    return { id: item.id, type: item.item_type, label: item.label };
  } catch (e) {
    await client.query('ROLLBACK');
    if (e instanceof HttpError) throw e;
    if (e.code === '23503') throw new HttpError(409, 'Restore the related course first, then restore this item.');
    throw e;
  } finally {
    client.release();
  }
}

async function listItems(userId) {
  await purgeExpired();
  const res = await db.query(
    `SELECT id, item_type AS type, label, deleted_at AS "deletedAt", expires_at AS "expiresAt"
       FROM recycle_bin WHERE user_id = $1 ORDER BY deleted_at DESC`,
    [userId],
  );
  return res.rows;
}

async function permanentlyDelete(userId, id) {
  await purgeExpired();
  const res = await db.query('SELECT * FROM recycle_bin WHERE id = $1 AND user_id = $2', [id, userId]);
  const item = res.rows[0];
  if (!item) throw new HttpError(404, 'Recycle-bin item not found or expired');
  await db.query('DELETE FROM recycle_bin WHERE id = $1 AND user_id = $2', [id, userId]);
  try {
    const payload = typeof item.payload_json === 'string' ? JSON.parse(item.payload_json) : item.payload_json;
    await attachments.removeForRecycleItem(userId, item.item_type, payload);
  } catch {}
}

module.exports = { listItems, permanentlyDelete, purgeExpired, restoreRecord, trashRecord };
