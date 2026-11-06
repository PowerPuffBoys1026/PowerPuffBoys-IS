/**
 * End-to-end smoke test. Creates and removes a uniquely named PostgreSQL
 * database so it never touches application data.
 *   npm run smoke
 */
const path = require('node:path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

process.env.PORT = process.env.SMOKE_PORT || '3999';
process.env.JWT_SECRET = 'smoke-secret';

const BASE = `http://localhost:${process.env.PORT}/api`;
let passed = 0;

function check(name, condition) {
  if (!condition) throw new Error(`FAIL: ${name}`);
  passed += 1;
  console.log(`  ok  ${name}`);
}

async function req(method, url, { token, body } = {}) {
  const res = await fetch(BASE + url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, json: text ? JSON.parse(text) : null };
}

async function main() {
  const testDatabase = `classmate_smoke_${process.pid}_${Date.now()}`;
  const maintenance = new Client({
    host: process.env.PGHOST || 'localhost',
    port: Number(process.env.PGPORT) || 5432,
    database: process.env.PGMAINTENANCE_DB || 'postgres',
    user: process.env.PGUSER || 'postgres',
    password: process.env.PGPASSWORD,
  });
  let created = false;
  let server;
  let db;

  try {
    await maintenance.connect();
    await maintenance.query(`CREATE DATABASE "${testDatabase}"`);
    created = true;
    process.env.PGDATABASE = testDatabase;

    const app = require('../src/app');
    db = require('../src/db');
    await db.initDb();
    server = app.listen(process.env.PORT);
    await new Promise((resolve) => server.once('listening', resolve));
    console.log(`Smoke test against ${BASE}\n`);

    let r = await req('GET', '/health');
    check('health responds ok', r.status === 200 && r.json.status === 'ok');
    check('health reports database ok', r.json.database === 'ok');

    const email = `student+${Date.now()}@example.com`;
    r = await req('POST', '/auth/register', {
      body: { email, password: 'password123', fullName: 'Test Student' },
    });
    check('register returns 201 + token', r.status === 201 && !!r.json.token);
    const token = r.json.token;

    r = await req('POST', '/auth/register', {
      body: { email, password: 'password123', fullName: 'Test Student' },
    });
    check('duplicate email -> 409', r.status === 409);

    r = await req('POST', '/auth/register', { body: { email: 'not-an-email', password: 'x' } });
    check('invalid register -> 400 with details', r.status === 400 && Array.isArray(r.json.error.details));

    r = await req('GET', '/subjects');
    check('protected route without token -> 401', r.status === 401);

    r = await req('GET', '/subjects/abc', { token });
    check('invalid numeric id -> 400', r.status === 400);

    r = await req('GET', '/works?subjectId=abc', { token });
    check('invalid subjectId query -> 400', r.status === 400);

    r = await req('GET', '/works?dueBefore=notadate', { token });
    check('invalid dueBefore query -> 400', r.status === 400);

    r = await req('GET', '/attendance?from=2026-13-40', { token });
    check('invalid attendance date query -> 400', r.status === 400);

    r = await req('GET', '/notes?pinned=yes', { token });
    check('invalid boolean query -> 400', r.status === 400);

    r = await req('POST', '/auth/login', { body: { email, password: 'password123' } });
    check('login returns token', r.status === 200 && !!r.json.token);

    r = await req('POST', '/auth/login', { body: { email, password: 'wrong-password' } });
    check('wrong password -> 401', r.status === 401);

    r = await req('POST', '/subjects', {
      token,
      body: { code: 'CS101', title: 'Intro to Computing', units: 3 },
    });
    check('create subject -> 201', r.status === 201 && r.json.data.code === 'CS101');
    const subjectId = r.json.data.id;

    r = await req('PUT', `/subjects/${subjectId}`, { token, body: { instructor: 'Professor' } });
    check('update subject', r.status === 200 && r.json.data.instructor === 'Professor');

    r = await req('GET', '/subjects', { token });
    check('list subjects', r.status === 200 && r.json.data.length === 1);

    r = await req('POST', '/schedule', {
      token,
      body: { subjectId, dayOfWeek: 1, startTime: '08:00', endTime: '09:30', room: 'Lab 2' },
    });
    check('create schedule slot -> 201', r.status === 201);
    const slotId = r.json.data.id;

    r = await req('PUT', `/schedule/${slotId}`, { token, body: { startTime: '08:30' } });
    check('update schedule slot', r.status === 200 && r.json.data.startTime === '08:30');

    r = await req('POST', '/schedule', {
      token,
      body: { subjectId, dayOfWeek: 1, startTime: '25:00', endTime: '09:30' },
    });
    check('invalid time -> 400', r.status === 400);

    r = await req('POST', '/schedule', {
      token,
      body: { subjectId, dayOfWeek: 1, startTime: '10:00', endTime: '09:30' },
    });
    check('endTime before startTime -> 400', r.status === 400);

    r = await req('GET', '/schedule?day=1', { token });
    check('schedule filter matches day', r.status === 200 && r.json.data.length === 1);
    r = await req('GET', '/schedule?day=3', { token });
    check('schedule filter empty day', r.status === 200 && r.json.data.length === 0);

    const today = new Date().toISOString().slice(0, 10);

    r = await req('POST', '/attendance', {
      token,
      body: { subjectId, date: '2026-02-31', status: 'present' },
    });
    check('invalid calendar date -> 400', r.status === 400);

    r = await req('POST', '/attendance', {
      token,
      body: { subjectId, slotId, date: today, status: 'present' },
    });
    check('mark attendance -> 201', r.status === 201);
    check('attendance date is YYYY-MM-DD', r.json.data.date === today);
    const attendanceId = r.json.data.id;

    r = await req('PUT', `/attendance/${attendanceId}`, { token, body: { note: 'checked' } });
    check('update attendance record', r.status === 200 && r.json.data.note === 'checked');

    r = await req('POST', '/attendance', {
      token,
      body: { subjectId, slotId, date: today, status: 'absent' },
    });
    check('duplicate attendance -> 409', r.status === 409);

    r = await req('POST', '/attendance', {
      token,
      body: { subjectId, date: today, status: 'absent' },
    });
    check('mark attendance without slot -> 201', r.status === 201);
    const noSlotAttendanceId = r.json.data.id;

    r = await req('POST', '/attendance', {
      token,
      body: { subjectId, date: today, status: 'absent' },
    });
    check('duplicate attendance without slot -> 409', r.status === 409);

    r = await req('PUT', `/attendance/${noSlotAttendanceId}`, { token, body: { slotId } });
    check('attendance update cannot create a duplicate -> 409', r.status === 409);

    r = await req('GET', `/attendance?subjectId=${subjectId}&from=${today}&to=${today}`, { token });
    check('attendance filters', r.status === 200 && r.json.data.length === 2);

    r = await req('GET', '/attendance/summary', { token });
    const summary = r.json.data[0];
    check('summary counts present + absent', r.status === 200 && summary.present === 1 && summary.absent === 1);
    check('attendance rate is 50%', summary.attendanceRate === 50);
    check('absence warning flagged', summary.warning === true);

    const dueAt = new Date(Date.now() + 3 * 86400000).toISOString();
    r = await req('POST', '/works', {
      token,
      body: { title: 'Lab 1', subjectId, dueAt, priority: 'high' },
    });
    check('create school work -> 201', r.status === 201);
    check('work dueAt is ISO-8601', !Number.isNaN(Date.parse(r.json.data.dueAt)));
    const workId = r.json.data.id;

    r = await req('PUT', `/works/${workId}`, { token, body: { title: 'Lab assignment' } });
    check('update school work', r.status === 200 && r.json.data.title === 'Lab assignment');

    r = await req('PATCH', `/works/${workId}/status`, { token, body: { status: 'done' } });
    check('patch work status', r.status === 200 && r.json.data.status === 'done');

    r = await req('GET', '/dashboard/today', { token });
    check(
      'dashboard returns classes + dueSoon',
      r.status === 200 && Array.isArray(r.json.data.classes) && Array.isArray(r.json.data.dueSoon),
    );
    check('dashboard surfaces attendance warning', r.json.data.attendanceWarnings.length === 1);
    check('dashboard date is YYYY-MM-DD', /^\d{4}-\d{2}-\d{2}$/.test(r.json.data.date));

    const email2 = `other+${Date.now()}@example.com`;
    r = await req('POST', '/auth/register', {
      body: { email: email2, password: 'password123', fullName: 'Other Student' },
    });
    const token2 = r.json.token;
    r = await req('GET', `/subjects/${subjectId}`, { token: token2 });
    check('another user cannot read the subject -> 404', r.status === 404);

    r = await req('DELETE', `/works/${workId}`, { token });
    check('delete work -> 204', r.status === 204);
    r = await req('GET', '/works', { token });
    check('work list empty after delete', r.json.data.length === 0);

    r = await req('POST', '/notes', {
      token,
      body: { title: 'Study notes', content: 'PostgreSQL basics', isPinned: true, tags: 'study,db' },
    });
    check('create note', r.status === 201 && r.json.data.isPinned);
    const noteId = r.json.data.id;

    r = await req('GET', '/notes?pinned=true&tag=study&search=PostgreSQL', { token });
    check('filter notes', r.status === 200 && r.json.data.length === 1);

    r = await req('PUT', `/notes/${noteId}`, { token, body: { title: 'Updated notes' } });
    check('update note', r.status === 200 && r.json.data.title === 'Updated notes');

    r = await req('PATCH', `/notes/${noteId}/pin`, { token });
    check('toggle note pin', r.status === 200 && !r.json.data.isPinned);

    r = await req('DELETE', `/notes/${noteId}`, { token });
    check('delete note', r.status === 204);

    r = await req('POST', '/subjects', {
      token,
      body: { code: 'CS102', title: 'Data Structures' },
    });
    const otherSubjectId = r.json.data.id;

    r = await req('POST', '/schedule', {
      token,
      body: { subjectId: otherSubjectId, dayOfWeek: 2, startTime: '10:00', endTime: '11:00' },
    });
    const otherSlotId = r.json.data.id;

    r = await req('POST', '/attendance', {
      token,
      body: { subjectId, slotId: otherSlotId, date: today, status: 'present' },
    });
    check('attendance slot must belong to the subject -> 404', r.status === 404);

    console.log(`\nAll ${passed} checks passed.`);
  } finally {
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
    await maintenance.end();
  }
}

main().catch((err) => {
  console.error('\nSMOKE TEST FAILED');
  console.error(err);
  process.exit(1);
});
