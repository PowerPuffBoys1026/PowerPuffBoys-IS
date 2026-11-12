const db = require('../db');

const AttendanceModel = {
  subjectExistsAndOwned: async (subjectId, userId) => {
    const result = await db.query('SELECT fn_subject_owned($1, $2) AS exists', [subjectId, userId]);
    return Boolean(result.rows[0]?.exists);
  },

  slotExistsForSubjectAndUser: async (slotId, subjectId, userId) => {
    const result = await db.query('SELECT fn_slot_exists_for_subject_user($1, $2, $3) AS exists', [slotId, subjectId, userId]);
    return Boolean(result.rows[0]?.exists);
  },

  findDuplicate: async (subjectId, date, slotId, excludeId = null) => {
    const result = await db.query('SELECT * FROM fn_attendance_find_duplicate($1, $2, $3, $4)', [
      subjectId, date, slotId ?? null, excludeId,
    ]);
    return result.rows[0] || null;
  },

  create: async ({ subjectId, slotId, date, status, note }) => {
    const result = await db.query('SELECT * FROM fn_attendance_create($1, $2, $3, $4, $5)', [
      subjectId, slotId ?? null, date, status, note ?? null,
    ]);
    return result.rows[0];
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query('SELECT * FROM fn_attendance_get($1, $2)', [id, userId]);
    return result.rows[0] || null;
  },

  findAllByUserId: async (userId, { subjectId, from, to, limit, offset } = {}) => {
    const result = await db.query('SELECT * FROM fn_attendance_list($1, $2, $3, $4, $5, $6)', [
      userId,
      subjectId ? Number(subjectId) : null,
      from || null,
      to || null,
      limit ?? null,
      offset ?? null,
    ]);
    return result.rows;
  },

  update: async (id, updates, current, userId) => {
    const setSlot = Object.prototype.hasOwnProperty.call(updates, 'slotId');
    const setNote = Object.prototype.hasOwnProperty.call(updates, 'note');
    const result = await db.query('SELECT * FROM fn_attendance_update($1, $2, $3, $4, $5, $6, $7, $8, $9)', [
      id,
      userId,
      updates.subjectId ?? current.subject_id,
      setSlot ? (updates.slotId ?? null) : null,
      setSlot,
      updates.date ?? current.date,
      updates.status ?? current.status,
      setNote ? (updates.note ?? null) : null,
      setNote,
    ]);
    return result.rows[0] || null;
  },

  delete: (id, userId) => db.query('SELECT fn_attendance_delete($1, $2) AS count', [id, userId]),
};

module.exports = AttendanceModel;
