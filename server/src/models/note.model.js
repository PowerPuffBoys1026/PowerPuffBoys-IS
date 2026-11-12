const db = require('../db');

function toBoolOrNull(v) {
  if (v === undefined || v === '') return null;
  return v === 'true' || v === true;
}

const NoteModel = {
  findAllByUserId: async (userId, { search, tag, pinned, subjectId, limit, offset } = {}) => {
    const result = await db.query('SELECT * FROM fn_note_list($1,$2,$3,$4,$5,$6,$7)', [
      userId,
      search || null,
      tag || null,
      toBoolOrNull(pinned),
      subjectId !== undefined && subjectId !== null && subjectId !== '' ? Number(subjectId) : null,
      limit ?? null,
      offset ?? null,
    ]);
    return result.rows;
  },

  create: async ({ userId, subjectId, title, content, isPinned, color, tags }) => {
    const result = await db.query('SELECT * FROM fn_note_create($1,$2,$3,$4,$5,$6,$7)', [
      userId, subjectId ?? null, title ?? 'Untitled', content ?? '', Boolean(isPinned), color ?? '#1C223D', tags ?? null,
    ]);
    return result.rows[0];
  },

  findByIdAndUserId: async (id, userId) => {
    const result = await db.query('SELECT * FROM fn_note_get($1, $2)', [id, userId]);
    return result.rows[0] || null;
  },

  update: async (id, updates, current, userId) => {
    const setSubject = Object.prototype.hasOwnProperty.call(updates, 'subjectId');
    const setColor = Object.prototype.hasOwnProperty.call(updates, 'color');
    const setTags = Object.prototype.hasOwnProperty.call(updates, 'tags');
    const result = await db.query('SELECT * FROM fn_note_update($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)', [
      id,
      userId,
      setSubject ? (updates.subjectId ?? null) : null,
      setSubject,
      updates.title ?? current.title,
      updates.content ?? current.content,
      updates.isPinned !== undefined ? updates.isPinned : current.is_pinned,
      setColor ? (updates.color ?? null) : null,
      setColor,
      setTags ? (updates.tags ?? null) : null,
      setTags,
    ]);
    return result.rows[0] || null;
  },

  togglePin: async (id, userId) => {
    const result = await db.query('SELECT * FROM fn_note_toggle_pin($1, $2)', [id, userId]);
    return result.rows[0] || null;
  },

  delete: (id, userId) => db.query('SELECT fn_note_delete($1, $2) AS count', [id, userId]),
  subjectExistsAndOwned: async (subjectId, userId) => {
    if (subjectId == null) return true;
    const r = await db.query('SELECT fn_subject_owned($1, $2) AS exists', [subjectId, userId]);
    return Boolean(r.rows[0]?.exists);
  },
};

module.exports = NoteModel;
