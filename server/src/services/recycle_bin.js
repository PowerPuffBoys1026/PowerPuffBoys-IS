const db = require('../db');
const { HttpError } = require('../utils/errors');
const attachments = require('./attachments');

const ITEM_CONFIG = {
  note: {
    table: 'subject_notes',
    label: row => row.title,
    select: 'SELECT * FROM subject_notes WHERE id = ? AND user_id = ?',
    remove: 'DELETE FROM subject_notes WHERE id = ?',
  },
  task: {
    table: 'school_works',
    label: row => row.title,
    select: 'SELECT * FROM school_works WHERE id = ? AND user_id = ?',
    remove: 'DELETE FROM school_works WHERE id = ?',
  },
  session: {
    table: 'study_sessions',
    label: row => `Study session (${row.duration_minutes} min)`,
    select: 'SELECT * FROM study_sessions WHERE id = ? AND user_id = ?',
    remove: 'DELETE FROM study_sessions WHERE id = ?',
  },
  grade: {
    table: 'subject_grades',
    label: row => row.component_name,
    select: 'SELECT * FROM subject_grades WHERE id = ? AND user_id = ?',
    remove: 'DELETE FROM subject_grades WHERE id = ?',
  },
  schedule: {
    table: 'schedule_slots',
    label: row => {
      const subject = db.prepare('SELECT code FROM subjects WHERE id = ?').get(row.subject_id);
      return `${subject?.code || 'Course'} timetable class`;
    },
    select: `SELECT slot.* FROM schedule_slots slot
      JOIN subjects subject ON subject.id = slot.subject_id
      WHERE slot.id = ? AND subject.user_id = ?`,
    remove: 'DELETE FROM schedule_slots WHERE id = ?',
  },
  attendance: {
    table: 'attendance_records',
    label: row => `${row.date} attendance (${row.status})`,
    select: `SELECT record.* FROM attendance_records record
      JOIN subjects subject ON subject.id = record.subject_id
      WHERE record.id = ? AND subject.user_id = ?`,
    remove: 'DELETE FROM attendance_records WHERE id = ?',
  },
};

const EXPIRED_DELETE = db.prepare("DELETE FROM recycle_bin WHERE expires_at <= datetime('now')");
const EXPIRED_SELECT = db.prepare("SELECT * FROM recycle_bin WHERE expires_at <= datetime('now')");

function purgeExpired() {
  for (const item of EXPIRED_SELECT.all()) {
    attachments.removeForRecycleItem(item.user_id, item.item_type, JSON.parse(item.payload_json));
  }
  EXPIRED_DELETE.run();
}

function saveToBin(userId, type, label, payload) {
  return db.prepare(
    `INSERT INTO recycle_bin (user_id, item_type, label, payload_json, deleted_at, expires_at)
     VALUES (?, ?, ?, ?, datetime('now'), datetime('now', '+30 days'))`,
  ).run(userId, type, label, JSON.stringify(payload)).lastInsertRowid;
}

function trashRecord(userId, type, id) {
  const config = ITEM_CONFIG[type];
  if (type !== 'subject' && !config) throw new HttpError(400, 'Unsupported recycle-bin item type');

  purgeExpired();
  return db.transaction(() => {
    if (type === 'subject') {
      const subject = db.prepare('SELECT * FROM subjects WHERE id = ? AND user_id = ?').get(id, userId);
      if (!subject) throw new HttpError(404, 'Subject not found');

      const payload = {
        subject,
        schedule: db.prepare('SELECT * FROM schedule_slots WHERE subject_id = ?').all(id),
        attendance: db.prepare('SELECT * FROM attendance_records WHERE subject_id = ?').all(id),
        grades: db.prepare('SELECT * FROM subject_grades WHERE subject_id = ? AND user_id = ?').all(id, userId),
        tasks: db.prepare('SELECT * FROM school_works WHERE subject_id = ? AND user_id = ?').all(id, userId),
        sessions: db.prepare('SELECT * FROM study_sessions WHERE subject_id = ? AND user_id = ?').all(id, userId),
        notes: db.prepare('SELECT * FROM subject_notes WHERE subject_id = ? AND user_id = ?').all(id, userId),
      };
      const binId = saveToBin(userId, type, `${subject.code} · ${subject.title}`, payload);
      for (const row of payload.tasks) db.prepare('DELETE FROM school_works WHERE id = ? AND user_id = ?').run(row.id, userId);
      for (const row of payload.sessions) db.prepare('DELETE FROM study_sessions WHERE id = ? AND user_id = ?').run(row.id, userId);
      for (const row of payload.notes) db.prepare('DELETE FROM subject_notes WHERE id = ? AND user_id = ?').run(row.id, userId);
      db.prepare('DELETE FROM subjects WHERE id = ?').run(id);
      return binId;
    }

    const row = db.prepare(config.select).get(id, userId);
    if (!row) throw new HttpError(404, 'Item not found');
    const binId = saveToBin(userId, type, config.label(row), row);
    db.prepare(config.remove).run(id);
    return binId;
  })();
}

function insertSnapshot(table, row) {
  const columns = Object.keys(row);
  const placeholders = columns.map(() => '?').join(', ');
  db.prepare(`INSERT INTO ${table} (${columns.join(', ')}) VALUES (${placeholders})`)
    .run(...columns.map(column => row[column]));
}

function restoreRecord(userId, id) {
  purgeExpired();
  try {
    return db.transaction(() => {
      const item = db.prepare('SELECT * FROM recycle_bin WHERE id = ? AND user_id = ?').get(id, userId);
      if (!item) throw new HttpError(404, 'Recycle-bin item not found or expired');
      const payload = JSON.parse(item.payload_json);

      if (item.item_type === 'subject') {
        insertSnapshot('subjects', payload.subject);
        for (const row of payload.schedule) insertSnapshot('schedule_slots', row);
        for (const row of payload.attendance) insertSnapshot('attendance_records', row);
        for (const row of payload.grades) insertSnapshot('subject_grades', row);
        for (const row of payload.tasks) insertSnapshot('school_works', row);
        for (const row of payload.sessions) insertSnapshot('study_sessions', row);
        for (const row of payload.notes) insertSnapshot('subject_notes', row);
      } else {
        const config = ITEM_CONFIG[item.item_type];
        if (!config) throw new HttpError(400, 'Unsupported recycle-bin item type');
        if (item.item_type === 'attendance' && payload.slot_id !== null) {
          const slot = db.prepare('SELECT id FROM schedule_slots WHERE id = ?').get(payload.slot_id);
          if (!slot) payload.slot_id = null;
        }
        insertSnapshot(config.table, payload);
      }

      db.prepare('DELETE FROM recycle_bin WHERE id = ?').run(id);
      return { id: item.id, type: item.item_type, label: item.label };
    })();
  } catch (error) {
    if (error instanceof HttpError) throw error;
    if (error.code === 'SQLITE_CONSTRAINT_FOREIGNKEY') {
      throw new HttpError(409, 'Restore the related course first, then restore this item.');
    }
    throw error;
  }
}

function listItems(userId) {
  purgeExpired();
  return db.prepare(
    `SELECT id, item_type AS type, label, deleted_at AS deletedAt, expires_at AS expiresAt
       FROM recycle_bin WHERE user_id = ? ORDER BY deleted_at DESC`,
  ).all(userId);
}

function permanentlyDelete(userId, id) {
  purgeExpired();
  const item = db.prepare('SELECT * FROM recycle_bin WHERE id = ? AND user_id = ?').get(id, userId);
  if (!item) throw new HttpError(404, 'Recycle-bin item not found or expired');
  db.prepare('DELETE FROM recycle_bin WHERE id = ? AND user_id = ?').run(id, userId);
  attachments.removeForRecycleItem(userId, item.item_type, JSON.parse(item.payload_json));
}

module.exports = { listItems, permanentlyDelete, purgeExpired, restoreRecord, trashRecord };