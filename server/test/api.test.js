/**
 * API integration tests. Each run creates a throwaway PostgreSQL database and
 * drops it afterwards, so local and CI application data are never touched.
 */
const path = require('node:path');
const { once } = require('node:events');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

process.env.JWT_SECRET ||= 'test-secret';
process.env.APP_TIMEZONE ||= 'Asia/Manila';

const test = require('node:test');
const assert = require('node:assert/strict');
const { Client } = require('pg');

const testDatabase = `classmate_test_${process.pid}_${Date.now()}`;
let maintenance;
let created = false;
let server;
let db;
let base;

async function req(method, url, { token, body } = {}) {
  const allowsBody = method !== 'GET' && method !== 'HEAD';
  const response = await fetch(base + url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined || !allowsBody ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  return { status: response.status, body: text ? JSON.parse(text) : null };
}

async function register(email, fullName = 'API Test') {
  const result = await req('POST', '/auth/register', {
    body: { email, password: 'password123', fullName },
  });
  assert.equal(result.status, 201);
  return result.body.token;
}

test.before(async () => {
  maintenance = new Client({
    host: process.env.PGHOST || 'localhost',
    port: Number(process.env.PGPORT) || 5432,
    database: process.env.PGMAINTENANCE_DB || 'postgres',
    user: process.env.PGUSER || 'postgres',
    password: process.env.PGPASSWORD,
  });
  await maintenance.connect();
  await maintenance.query(`CREATE DATABASE "${testDatabase}"`);
  created = true;

  process.env.PGDATABASE = testDatabase;

  const app = require('../src/app');
  db = require('../src/db');
  await db.initDb();

  server = app.listen(0);
  await once(server, 'listening');
  base = `http://127.0.0.1:${server.address().port}/api`;
});

test.after(async () => {
  if (server) {
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
  if (db) await db.end();
  if (created) {
    await maintenance.query(
      'SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = $1 AND pid <> pg_backend_pid()',
      [testDatabase],
    );
    await maintenance.query(`DROP DATABASE "${testDatabase}"`);
  }
  if (maintenance) await maintenance.end();
});

test('health reports the database as available', async () => {
  const result = await req('GET', '/health');
  assert.equal(result.status, 200);
  assert.equal(result.body.status, 'ok');
  assert.equal(result.body.database, 'ok');
});

test('register, login, and auth/me work', async () => {
  const email = `api+${Date.now()}@example.com`;
  const token = await register(email);
  assert.ok(token);

  const login = await req('POST', '/auth/login', {
    body: { email, password: 'password123' },
  });
  assert.equal(login.status, 200);
  assert.ok(login.body.token);

  const me = await req('GET', '/auth/me', { token });
  assert.equal(me.status, 200);
  assert.equal(me.body.data.email, email);
});

test('protected routes reject missing and invalid tokens', async () => {
  const missing = await req('GET', '/subjects');
  assert.equal(missing.status, 401);

  const invalid = await req('GET', '/subjects', { token: 'not-a-jwt' });
  assert.equal(invalid.status, 401);
});

test('subject CRUD, validation, and pagination', async () => {
  const token = await register(`subject+${Date.now()}@example.com`);

  const invalid = await req('POST', '/subjects', {
    token,
    body: { code: '', title: '' },
  });
  assert.equal(invalid.status, 400);

  const created = await req('POST', '/subjects', {
    token,
    body: { code: 'CS101', title: 'Intro to Computing', units: 3 },
  });
  assert.equal(created.status, 201);
  const subjectId = created.body.data.id;

  const updated = await req('PUT', `/subjects/${subjectId}`, {
    token,
    body: { instructor: 'Professor' },
  });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.data.instructor, 'Professor');

  const badLimit = await req('GET', '/subjects?limit=0', { token });
  assert.equal(badLimit.status, 400);

  const badOffset = await req('GET', '/subjects?offset=-1', { token });
  assert.equal(badOffset.status, 400);

  const firstPage = await req('GET', '/subjects?limit=1', { token });
  assert.equal(firstPage.status, 200);
  assert.equal(firstPage.body.data.length, 1);

  const secondPage = await req('GET', '/subjects?limit=1&offset=1', { token });
  assert.equal(secondPage.status, 200);
  assert.equal(secondPage.body.data.length, 0);
});

test('one user cannot read or mutate another user\'s resources', async () => {
  const owner = await register(`owner+${Date.now()}@example.com`);
  const other = await register(`other+${Date.now()}@example.com`);

  const subject = await req('POST', '/subjects', {
    token: owner,
    body: { code: 'SEC101', title: 'Security' },
  });
  const subjectId = subject.body.data.id;

  const work = await req('POST', '/works', {
    token: owner,
    body: { title: 'Private work', subjectId },
  });
  const workId = work.body.data.id;

  const note = await req('POST', '/notes', {
    token: owner,
    body: { title: 'Private note' },
  });
  const noteId = note.body.data.id;

  const slot = await req('POST', '/schedule', {
    token: owner,
    body: { subjectId, dayOfWeek: 1, startTime: '08:00', endTime: '09:30' },
  });
  const slotId = slot.body.data.id;

  const attendance = await req('POST', '/attendance', {
    token: owner,
    body: { subjectId, slotId, date: '2026-01-15', status: 'present' },
  });
  const attendanceId = attendance.body.data.id;

  const attempts = [
    ['GET', `/subjects/${subjectId}`],
    ['PUT', `/subjects/${subjectId}`, {}],
    ['DELETE', `/subjects/${subjectId}`],
    ['PUT', `/works/${workId}`, {}],
    ['PATCH', `/works/${workId}/status`, { status: 'todo' }],
    ['DELETE', `/works/${workId}`],
    ['PUT', `/notes/${noteId}`, {}],
    ['PATCH', `/notes/${noteId}/pin`],
    ['DELETE', `/notes/${noteId}`],
    ['PUT', `/schedule/${slotId}`, {}],
    ['DELETE', `/schedule/${slotId}`],
    ['PUT', `/attendance/${attendanceId}`, {}],
    ['DELETE', `/attendance/${attendanceId}`],
  ];

  for (const [method, url, body] of attempts) {
    const result = await req(method, url, { token: other, body });
    assert.equal(result.status, 404, `${method} ${url} should return 404`);
  }
});

test('schedule slots validate times and ownership', async () => {
  const token = await register(`schedule+${Date.now()}@example.com`);
  const subject = await req('POST', '/subjects', {
    token,
    body: { code: 'SCH101', title: 'Scheduling' },
  });
  const subjectId = subject.body.data.id;

  const backwards = await req('POST', '/schedule', {
    token,
    body: { subjectId, dayOfWeek: 1, startTime: '10:00', endTime: '09:30' },
  });
  assert.equal(backwards.status, 400);

  const created = await req('POST', '/schedule', {
    token,
    body: { subjectId, dayOfWeek: 1, startTime: '08:00', endTime: '09:30', room: 'Lab 2' },
  });
  assert.equal(created.status, 201);
  assert.equal(created.body.data.startTime, '08:00');
  assert.equal(created.body.data.endTime, '09:30');

  const filtered = await req('GET', '/schedule?day=1', { token });
  assert.equal(filtered.status, 200);
  assert.equal(filtered.body.data.length, 1);

  const empty = await req('GET', '/schedule?day=3', { token });
  assert.equal(empty.status, 200);
  assert.equal(empty.body.data.length, 0);
});

test('school works support updates, status changes, and filters', async () => {
  const token = await register(`works+${Date.now()}@example.com`);
  const subject = await req('POST', '/subjects', {
    token,
    body: { code: 'WRK101', title: 'Works' },
  });
  const subjectId = subject.body.data.id;
  const dueAt = new Date(Date.now() + 3 * 86400000).toISOString();

  const created = await req('POST', '/works', {
    token,
    body: { title: 'Lab 1', subjectId, dueAt, priority: 'high' },
  });
  assert.equal(created.status, 201);
  const workId = created.body.data.id;

  const updated = await req('PUT', `/works/${workId}`, {
    token,
    body: { title: 'Lab assignment' },
  });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.data.title, 'Lab assignment');

  const status = await req('PATCH', `/works/${workId}/status`, {
    token,
    body: { status: 'done' },
  });
  assert.equal(status.status, 200);
  assert.equal(status.body.data.status, 'done');

  const done = await req('GET', '/works?status=done', { token });
  assert.equal(done.status, 200);
  assert.equal(done.body.data.length, 1);

  const deleted = await req('DELETE', `/works/${workId}`, { token });
  assert.equal(deleted.status, 200);
  assert.ok(deleted.body.data.recycleBinId);

  const hidden = await req('GET', `/works/${workId}`, { token });
  assert.equal(hidden.status, 404);

  const bin = await req('GET', '/recycle-bin', { token });
  assert.equal(bin.status, 200);
  assert.ok(bin.body.data.some((item) => item.id === deleted.body.data.recycleBinId && item.type === 'task'));

  const restored = await req('POST', `/recycle-bin/${deleted.body.data.recycleBinId}/restore`, { token });
  assert.equal(restored.status, 200);

  const visibleAgain = await req('GET', `/works/${workId}`, { token });
  assert.equal(visibleAgain.status, 200);
  assert.equal(visibleAgain.body.data.title, 'Lab assignment');
});

test('attendance rejects duplicate sessions and produces a summary', async () => {
  const token = await register(`attendance+${Date.now()}@example.com`);
  const subject = await req('POST', '/subjects', {
    token,
    body: { code: 'ATT101', title: 'Attendance' },
  });
  const subjectId = subject.body.data.id;

  const slot = await req('POST', '/schedule', {
    token,
    body: { subjectId, dayOfWeek: 2, startTime: '10:00', endTime: '11:00' },
  });
  const slotId = slot.body.data.id;

  const created = await req('POST', '/attendance', {
    token,
    body: { subjectId, slotId, date: '2026-01-16', status: 'present' },
  });
  assert.equal(created.status, 201);
  assert.equal(created.body.data.date, '2026-01-16');

  const duplicate = await req('POST', '/attendance', {
    token,
    body: { subjectId, slotId, date: '2026-01-16', status: 'absent' },
  });
  assert.equal(duplicate.status, 409);

  const summary = await req('GET', '/attendance/summary', { token });
  assert.equal(summary.status, 200);
  assert.equal(summary.body.data.length, 1);
  assert.equal(summary.body.data[0].present, 1);
});

test('note search treats LIKE wildcards literally', async () => {
  const token = await register(`notes+${Date.now()}@example.com`);

  await req('POST', '/notes', {
    token,
    body: { title: '100% complete', content: 'literal percent' },
  });
  await req('POST', '/notes', {
    token,
    body: { title: 'ordinary note', content: 'nothing special' },
  });

  const literal = await req('GET', `/notes?search=${encodeURIComponent('%')}`, { token });
  assert.equal(literal.status, 200);
  assert.equal(literal.body.data.length, 1);
  assert.equal(literal.body.data[0].title, '100% complete');

  const underscore = await req('GET', `/notes?search=${encodeURIComponent('_')}`, { token });
  assert.equal(underscore.status, 200);
  assert.equal(underscore.body.data.length, 0);
});

test('dashboard returns today\'s shape', async () => {
  const token = await register(`dashboard+${Date.now()}@example.com`);
  const result = await req('GET', '/dashboard/today', { token });

  assert.equal(result.status, 200);
  assert.match(result.body.data.date, /^\d{4}-\d{2}-\d{2}$/);
  assert.ok(Array.isArray(result.body.data.classes));
  assert.ok(Array.isArray(result.body.data.dueSoon));
  assert.ok(Array.isArray(result.body.data.attendanceWarnings));
});
