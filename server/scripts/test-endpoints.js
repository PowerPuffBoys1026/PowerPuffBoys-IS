const assert = require('node:assert');
const app = require('../src/app');
const db = require('../src/db');
const jwt = require('jsonwebtoken');
const config = require('../src/config');

console.log('Testing new endpoints directly against Express app handlers...\n');

// Get demo user
const user = db.prepare('SELECT * FROM users WHERE email = ?').get('demo@classmate.app');
assert(user, 'Demo user must exist');
const token = jwt.sign({ sub: user.id }, config.jwtSecret, { expiresIn: '1h' });

function mockReqRes(options) {
  const req = {
    method: options.method || 'GET',
    url: options.url || '/',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      ...options.headers,
    },
    body: options.body || {},
    query: options.query || {},
    params: options.params || {},
  };

  return new Promise((resolve) => {
    const res = {
      statusCode: 200,
      headers: {},
      status(code) {
        this.statusCode = code;
        return this;
      },
      setHeader(name, value) {
        this.headers[name] = value;
      },
      json(data) {
        this.body = data;
        resolve({ status: this.statusCode, body: data });
      },
      send(data) {
        this.body = data;
        resolve({ status: this.statusCode, body: data });
      },
    };

    app.handle(req, res);
  });
}

async function run() {
  // 1. Health check
  let res = await mockReqRes({ method: 'GET', url: '/api/health' });
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.status, 'ok');
  assert(res.body.features.includes('study'));
  console.log('  ok  /api/health');

  // 2. Study sessions
  res = await mockReqRes({ method: 'GET', url: '/api/study/sessions' });
  assert.strictEqual(res.status, 200);
  assert(Array.isArray(res.body.data));
  console.log(`  ok  GET /api/study/sessions (${res.body.data.length} sessions)`);

  // 3. Study stats
  res = await mockReqRes({ method: 'GET', url: '/api/study/stats' });
  assert.strictEqual(res.status, 200);
  assert(res.body.data.totalSessionsAllTime >= 0);
  console.log(`  ok  GET /api/study/stats (streak: ${res.body.data.streakDays} days)`);

  // 4. Create study session
  res = await mockReqRes({
    method: 'POST',
    url: '/api/study/sessions',
    body: { durationMinutes: 25, mode: 'focus', notes: 'Completed reading Chapter 3' },
  });
  assert.strictEqual(res.status, 201);
  assert.strictEqual(res.body.data.durationMinutes, 25);
  console.log('  ok  POST /api/study/sessions');

  // 5. Notes
  res = await mockReqRes({ method: 'GET', url: '/api/notes' });
  assert.strictEqual(res.status, 200);
  assert(Array.isArray(res.body.data));
  console.log(`  ok  GET /api/notes (${res.body.data.length} notes)`);

  // 6. Create note
  res = await mockReqRes({
    method: 'POST',
    url: '/api/notes',
    body: { title: 'Exam Review Checklist', content: 'Formulas, Lemmas, Definitions', isPinned: true },
  });
  assert.strictEqual(res.status, 201);
  assert.strictEqual(res.body.data.title, 'Exam Review Checklist');
  console.log('  ok  POST /api/notes');

  // 7. Grades summary
  res = await mockReqRes({ method: 'GET', url: '/api/grades/summary' });
  assert.strictEqual(res.status, 200);
  assert(res.body.data.subjects !== undefined);
  console.log(`  ok  GET /api/grades/summary (GPA: ${res.body.data.cumulativeGpa})`);

  // 8. Attendance summary with safeMissesLeft
  res = await mockReqRes({ method: 'GET', url: '/api/attendance/summary' });
  assert.strictEqual(res.status, 200);
  assert(Array.isArray(res.body.data));
  if (res.body.data.length > 0) {
    assert(res.body.data[0].safeMissesLeft !== undefined);
    assert(res.body.data[0].healthStatus !== undefined);
  }
  console.log('  ok  GET /api/attendance/summary (includes cut calculator & safeMissesLeft)');

  console.log('\nAll new backend routes verified successfully! ✨');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
