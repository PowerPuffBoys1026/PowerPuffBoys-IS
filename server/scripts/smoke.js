/**
 * End-to-end smoke test. Uses an isolated port and a throwaway database so it
 * never touches real data.
 *   npm run smoke
 */
const path = require('node:path');
const fs = require('node:fs');

process.env.PORT = process.env.SMOKE_PORT || '3999';
process.env.DB_FILE = path.join(__dirname, '..', 'data', 'smoke.db');
process.env.JWT_SECRET = 'smoke-secret';

// Start from a clean database.
for (const suffix of ['', '-wal', '-shm']) {
  const file = process.env.DB_FILE + suffix;
  if (fs.existsSync(file)) fs.unlinkSync(file);
}

const app = require('../src/app');

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
  const server = app.listen(process.env.PORT);
  await new Promise((resolve) => server.once('listening', resolve));
  console.log(`Smoke test against ${BASE}\n`);

  let r = await req('GET', '/health');
  check('health responds ok', r.status === 200 && r.json.status === 'ok');

  const email = `student+${Date.now()}@example.com`;
  r = await req('POST', '/auth/register', { body: { email, password: 'password123', fullName: 'Test Student' } });
  check('register returns 201 + token', r.status === 201 && !!r.json.token);
  const token = r.json.token;

  r = await req('POST', '/auth/register', { body: { email, password: 'password123', fullName: 'Test Student' } });
  check('duplicate email -> 409', r.status === 409);

  r = await req('POST', '/auth/register', { body: { email: 'not-an-email', password: 'x' } });
  check('invalid register -> 400 with details', r.status === 400 && Array.isArray(r.json.error.details));

  r = await req('GET', '/subjects');
  check('protected route without token -> 401', r.status === 401);

  r = await req('POST', '/auth/login', { body: { email, password: 'password123' } });
  check('login returns token', r.status === 200 && !!r.json.token);

  r = await req('POST', '/auth/login', { body: { email, password: 'wrong-password' } });
  check('wrong password -> 401', r.status === 401);

  r = await req('POST', '/subjects', { token, body: { code: 'CS101', title: 'Intro to Computing', units: 3 } });
  check('create subject -> 201', r.status === 201 && r.json.data.code === 'CS101');
  const subjectId = r.json.data.id;

  r = await req('GET', '/subjects', { token });
  check('list subjects', r.status === 200 && r.json.data.length === 1);

  r = await req('POST', '/schedule', {
    token,
    body: { subjectId, dayOfWeek: 1, startTime: '08:00', endTime: '09:30', room: 'Lab 2' },
  });
  check('create schedule slot -> 201', r.status === 201);
  const slotId = r.json.data.id;

  r = await req('POST', '/schedule', { token, body: { subjectId, dayOfWeek: 1, startTime: '25:00', endTime: '09:30' } });
  check('invalid time -> 400', r.status === 400);

  r = await req('GET', '/schedule?day=1', { token });
  check('schedule filter matches day', r.status === 200 && r.json.data.length === 1);
  r = await req('GET', '/schedule?day=3', { token });
  check('schedule filter empty day', r.status === 200 && r.json.data.length === 0);

  const today = new Date().toISOString().slice(0, 10);
  r = await req('POST', '/attendance', { token, body: { subjectId, slotId, date: today, status: 'present' } });
  check('mark attendance -> 201', r.status === 201);

  r = await req('POST', '/attendance', { token, body: { subjectId, slotId, date: today, status: 'absent' } });
  check('duplicate attendance -> 409', r.status === 409);

  await req('POST', '/attendance', { token, body: { subjectId, date: today, status: 'absent' } });

  r = await req('GET', '/attendance/summary', { token });
  const summary = r.json.data[0];
  check('summary counts present + absent', r.status === 200 && summary.present === 1 && summary.absent === 1);
  check('attendance rate is 50%', summary.attendanceRate === 50);
  check('absence warning flagged', summary.warning === true);

  const dueAt = new Date(Date.now() + 3 * 86400000).toISOString();
  r = await req('POST', '/works', { token, body: { title: 'Lab 1', subjectId, dueAt, priority: 'high' } });
  check('create school work -> 201', r.status === 201);
  const workId = r.json.data.id;

  r = await req('PATCH', `/works/${workId}/status`, { token, body: { status: 'done' } });
  check('patch work status', r.status === 200 && r.json.data.status === 'done');

  r = await req('GET', '/dashboard/today', { token });
  check('dashboard returns classes + dueSoon', r.status === 200 && Array.isArray(r.json.data.classes) && Array.isArray(r.json.data.dueSoon));
  check('dashboard surfaces attendance warning', r.json.data.attendanceWarnings.length === 1);

  const email2 = `other+${Date.now()}@example.com`;
  r = await req('POST', '/auth/register', { body: { email: email2, password: 'password123', fullName: 'Other Student' } });
  const token2 = r.json.token;
  r = await req('GET', `/subjects/${subjectId}`, { token: token2 });
  check('another user cannot read the subject -> 404', r.status === 404);

  r = await req('DELETE', `/works/${workId}`, { token });
  check('delete work -> 204', r.status === 204);
  r = await req('GET', '/works', { token });
  check('work list empty after delete', r.json.data.length === 0);

  // Close the server and the SQLite handle before deleting the throwaway DB.
  await new Promise((resolve) => server.close(resolve));
  require('../src/db').close();
  for (const suffix of ['', '-wal', '-shm']) {
    const file = process.env.DB_FILE + suffix;
    if (fs.existsSync(file)) fs.unlinkSync(file);
  }

  console.log(`\nAll ${passed} checks passed.`);
}

main().catch((err) => {
  console.error('\nSMOKE TEST FAILED');
  console.error(err);
  process.exit(1);
});
