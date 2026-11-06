process.env.JWT_SECRET ||= 'test-secret';
process.env.APP_TIMEZONE ||= 'Asia/Manila';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  parseId,
  parseOptionalInt,
  parseOptionalDate,
  parseOptionalBoolean,
  parseOptionalString,
  parseOptionalEnum,
  parsePagination,
} = require('../src/utils/parse');
const { dateInTimeZone, dayOfWeekInTimeZone } = require('../src/utils/dates');

function expect400(fn) {
  assert.throws(fn, (error) => error.status === 400);
}

test('parseId accepts positive integers only', () => {
  assert.equal(parseId('42'), 42);
  assert.equal(parseId(7), 7);
  expect400(() => parseId('abc'));
  expect400(() => parseId('0'));
  expect400(() => parseId('-3'));
  expect400(() => parseId('1.5'));
});

test('parseOptionalInt enforces the inclusive range', () => {
  assert.equal(parseOptionalInt(undefined, { name: 'limit', min: 1, max: 100 }), undefined);
  assert.equal(parseOptionalInt('', { name: 'limit', min: 1, max: 100 }), undefined);
  assert.equal(parseOptionalInt('100', { name: 'limit', min: 1, max: 100 }), 100);
  expect400(() => parseOptionalInt('0', { name: 'limit', min: 1, max: 100 }));
  expect400(() => parseOptionalInt('101', { name: 'limit', min: 1, max: 100 }));
  expect400(() => parseOptionalInt(['1', '2'], { name: 'limit', min: 1, max: 100 }));
});

test('parseOptionalDate accepts only real calendar dates', () => {
  assert.equal(parseOptionalDate('2026-02-28', 'dueBefore'), '2026-02-28');
  assert.equal(parseOptionalDate(undefined, 'dueBefore'), undefined);
  expect400(() => parseOptionalDate('2026-02-31', 'dueBefore'));
  expect400(() => parseOptionalDate('2026-2-3', 'dueBefore'));
  expect400(() => parseOptionalDate('not-a-date', 'dueBefore'));
});

test('parseOptionalBoolean only accepts true/false', () => {
  assert.equal(parseOptionalBoolean('true', 'pinned'), true);
  assert.equal(parseOptionalBoolean('false', 'pinned'), false);
  assert.equal(parseOptionalBoolean(true, 'pinned'), true);
  assert.equal(parseOptionalBoolean(undefined, 'pinned'), undefined);
  expect400(() => parseOptionalBoolean('yes', 'pinned'));
});

test('parseOptionalString rejects arrays and oversized values', () => {
  assert.equal(parseOptionalString('abc', 'search'), 'abc');
  assert.equal(parseOptionalString('', 'search'), undefined);
  expect400(() => parseOptionalString(['a'], 'search'));
  expect400(() => parseOptionalString('x'.repeat(201), 'search'));
  assert.equal(parseOptionalString('x'.repeat(201), 'search', { maxLength: 300 }).length, 201);
});

test('parseOptionalEnum restricts values to the allowlist', () => {
  assert.equal(parseOptionalEnum('done', 'status', ['todo', 'doing', 'done']), 'done');
  assert.equal(parseOptionalEnum('', 'status', ['todo']), undefined);
  expect400(() => parseOptionalEnum('archived', 'status', ['todo', 'doing', 'done']));
});

test('parsePagination validates limit and offset', () => {
  assert.deepEqual(parsePagination({}), { limit: undefined, offset: undefined });
  assert.deepEqual(parsePagination({ limit: '25', offset: '10' }), { limit: 25, offset: 10 });
  assert.deepEqual(parsePagination({ limit: '5' }, { maxLimit: 5 }), { limit: 5, offset: undefined });
  expect400(() => parsePagination({ limit: '0' }));
  expect400(() => parsePagination({ limit: '101' }));
  expect400(() => parsePagination({ offset: '-1' }));
});

test('dateInTimeZone respects the requested IANA zone', () => {
  const instant = new Date('2026-01-01T16:30:00Z');
  assert.equal(dateInTimeZone(instant, 'UTC'), '2026-01-01');
  assert.equal(dateInTimeZone(instant, 'Asia/Manila'), '2026-01-02');
  assert.equal(dateInTimeZone(new Date('2026-11-06T03:00:00Z'), 'America/Los_Angeles'), '2026-11-05');
});

test('dayOfWeekInTimeZone is computed from the local calendar date', () => {
  assert.equal(dayOfWeekInTimeZone(new Date('2026-11-06T12:00:00Z'), 'Asia/Manila'), 5); // Friday
  assert.equal(dayOfWeekInTimeZone(new Date('2026-01-01T16:30:00Z'), 'Asia/Manila'), 5); // Jan 2, Friday
  assert.equal(dayOfWeekInTimeZone(new Date('2026-11-08T12:00:00Z'), 'UTC'), 0); // Sunday
});
