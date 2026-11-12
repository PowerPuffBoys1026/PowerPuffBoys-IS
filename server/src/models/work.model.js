const db = require('../db');

const WorkModel = {
  subjectExistsAndOwned: async (subjectId, userId) => {
    if (subjectId === undefined || subjectId === null) return true;
    const result = await db.query('SELECT fn_subject_owned($1, $2) AS exists', [subjectId, userId]);
    return Boolean(result.rows[0]?.exists);
  },

  findAllByUserId: async (userId, { status, subjectId, dueBefore, limit, offset } = {}) => {
    const result = await db.query('SELECT * FROM fn_work_list($1, $2, $3, $4, $5, $6)', [
      userId,
      status || null,
      subjectId ? Number(subjectId) : null,
      dueBefore || null,
      limit ?? null,
      offset ?? null,
    ]);
    return result.rows;
  },

  create: async ({ userId, subjectId, title, type, dueAt, priority, status, notes }) => {
    const result = await db.query('SELECT * FROM fn_work_create($1, $2, $3, $4, $5, $6, $7, $8)', [
      userId, subjectId ?? null, title, type ?? 'assignment', dueAt ?? null, priority ?? 'medium', status ?? 'todo', notes ?? null,
    ]);
    return result.rows[0];
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query('SELECT * FROM fn_work_get($1, $2)', [id, userId]);
    return result.rows[0] || null;
  },

  update: async (id, updates, current, userId) => {
    const setSubject = Object.prototype.hasOwnProperty.call(updates, 'subjectId');
    const setDue = Object.prototype.hasOwnProperty.call(updates, 'dueAt');
    const setNotes = Object.prototype.hasOwnProperty.call(updates, 'notes');
    const result = await db.query('SELECT * FROM fn_work_update($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)', [
      id,
      userId,
      setSubject ? (updates.subjectId ?? null) : null,
      setSubject,
      updates.title ?? current.title,
      updates.type ?? current.type,
      setDue ? (updates.dueAt ?? null) : null,
      setDue,
      updates.priority ?? current.priority,
      updates.status ?? current.status,
      setNotes ? (updates.notes ?? null) : null,
      setNotes,
    ]);
    return result.rows[0] || null;
  },

  updateStatus: async (id, status, userId) => {
    const result = await db.query('SELECT * FROM fn_work_update_status($1, $2, $3)', [id, userId, status]);
    return result.rows[0] || null;
  },

  delete: (id, userId) => db.query('SELECT fn_work_delete($1, $2) AS count', [id, userId]),
};

module.exports = WorkModel;
