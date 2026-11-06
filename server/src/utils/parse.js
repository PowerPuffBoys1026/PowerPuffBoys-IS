const { HttpError } = require('./errors');

/** Parse a positive integer route/query value, or throw a 400. */
function parseId(value, name = 'id') {
  const id = Number(value);
  if (!Number.isInteger(id) || id <= 0) {
    throw new HttpError(400, `${name} must be a positive integer`);
  }
  return id;
}

/** Parse an optional integer query value within an inclusive range. */
function parseOptionalInt(value, { name, min, max }) {
  if (value === undefined || value === '') return undefined;
  if (typeof value !== 'string') {
    throw new HttpError(400, `${name} must be a single integer`);
  }
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new HttpError(400, `${name} must be an integer between ${min} and ${max}`);
  }
  return parsed;
}

/** Parse an optional `YYYY-MM-DD` query value and verify it is a real date. */
function parseOptionalDate(value, name) {
  if (value === undefined || value === '') return undefined;
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new HttpError(400, `${name} must be a date in YYYY-MM-DD format`);
  }
  const date = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
    throw new HttpError(400, `${name} must be a valid date`);
  }
  return value;
}

/** Parse an optional boolean query value (`true`/`false`). */
function parseOptionalBoolean(value, name) {
  if (value === undefined || value === '') return undefined;
  if (value === true || value === 'true') return true;
  if (value === false || value === 'false') return false;
  throw new HttpError(400, `${name} must be true or false`);
}

/** Parse an optional single string query value, rejecting arrays/objects. */
function parseOptionalString(value, name, { maxLength = 200 } = {}) {
  if (value === undefined || value === '') return undefined;
  if (typeof value !== 'string') {
    throw new HttpError(400, `${name} must be a single string`);
  }
  if (value.length > maxLength) {
    throw new HttpError(400, `${name} must be at most ${maxLength} characters`);
  }
  return value;
}

/** Parse an optional enum query value. */
function parseOptionalEnum(value, name, allowed) {
  if (value === undefined || value === '') return undefined;
  if (typeof value !== 'string' || !allowed.includes(value)) {
    throw new HttpError(400, `${name} must be one of: ${allowed.join(', ')}`);
  }
  return value;
}

/** Parse optional `limit` / `offset` query values. */
function parsePagination(query = {}, { maxLimit = 100 } = {}) {
  return {
    limit: parseOptionalInt(query.limit, { name: 'limit', min: 1, max: maxLimit }),
    offset: parseOptionalInt(query.offset, {
      name: 'offset',
      min: 0,
      max: Number.MAX_SAFE_INTEGER,
    }),
  };
}

module.exports = {
  parseId,
  parseOptionalInt,
  parseOptionalDate,
  parseOptionalBoolean,
  parseOptionalString,
  parseOptionalEnum,
  parsePagination,
};
