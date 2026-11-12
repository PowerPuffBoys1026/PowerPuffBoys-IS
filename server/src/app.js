const path = require('node:path');
const fs = require('node:fs');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');

const config = require('./config');
const db = require('./db');
const { asyncHandler } = require('./utils/asyncHandler');
const { notFound, errorHandler } = require('./middleware/error');
const authRoutes = require('./routes/auth');
const subjectRoutes = require('./routes/subjects');
const scheduleRoutes = require('./routes/schedule');
const attendanceRoutes = require('./routes/attendance');
const workRoutes = require('./routes/works');
const dashboardRoutes = require('./routes/dashboard');
const noteRoutes = require('./routes/notes');
const studyRoutes = require('./routes/study');
const gradeRoutes = require('./routes/grades');
const attachmentRoutes = require('./routes/attachments');
const recycleBinRoutes = require('./routes/recycle_bin');

const app = express();

app.disable('x-powered-by');
// The API returns JSON and one small HTML landing page; helmet's default CSP
// would block that page's inline stylesheet.
app.use(helmet({ contentSecurityPolicy: false }));
app.use(
  cors({
    origin: config.corsOrigins.includes('*') ? true : config.corsOrigins,
  }),
);
app.use(express.json({ limit: '1mb' }));

// v2 web frontend (served from server/public)
const publicPath = path.join(__dirname, '..', 'public');
if (fs.existsSync(publicPath)) {
  app.use(express.static(publicPath));
}

const API_ENDPOINTS = [
  { method: 'GET', path: '/api/health', description: 'Health check (API + database)' },
  { method: 'POST', path: '/api/auth/register', description: 'Create an account' },
  { method: 'POST', path: '/api/auth/login', description: 'Log in and get a JWT' },
  { method: 'GET', path: '/api/auth/me', description: 'Current user' },
  { method: 'GET/POST', path: '/api/subjects', description: 'List / create subjects' },
  { method: 'GET/PUT/DELETE', path: '/api/subjects/:id', description: 'Read / update / delete a subject' },
  { method: 'GET/POST', path: '/api/schedule', description: 'List / create schedule slots' },
  { method: 'PUT/DELETE', path: '/api/schedule/:id', description: 'Update / delete a schedule slot' },
  { method: 'GET/POST', path: '/api/attendance', description: 'List / mark attendance' },
  { method: 'GET', path: '/api/attendance/summary', description: 'Attendance summary and warnings' },
  { method: 'PUT/DELETE', path: '/api/attendance/:id', description: 'Update / delete an attendance record' },
  { method: 'GET/POST', path: '/api/works', description: 'List / create school works' },
  { method: 'GET/PUT/DELETE', path: '/api/works/:id', description: 'Read / update / delete a school work' },
  { method: 'PATCH', path: '/api/works/:id/status', description: 'Change work status' },
  { method: 'GET/POST', path: '/api/notes', description: 'List / create notes' },
  { method: 'GET/PUT/DELETE', path: '/api/notes/:id', description: 'Read / update / delete a note' },
  { method: 'PATCH', path: '/api/notes/:id/pin', description: 'Toggle the pinned flag' },
  { method: 'GET', path: '/api/dashboard/today', description: "Today's classes, due works and warnings" },
];

// Browser-friendly landing page: http://localhost:3000
app.get('/', (req, res) => {
  const rows = API_ENDPOINTS.map((endpoint) => {
    const url = endpoint.path.includes(':')
      ? `<code>${endpoint.path}</code>`
      : `<a href="${endpoint.path}">${endpoint.path}</a>`;
    return `<tr><td><code>${endpoint.method}</code></td><td>${url}</td><td>${endpoint.description}</td></tr>`;
  }).join('');

  res.type('html').send(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ClassMate API</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 0; padding: 2rem; background: #f4f5fb; color: #1c223d; }
    main { max-width: 900px; margin: 0 auto; background: #fff; padding: 2rem; border-radius: 12px; box-shadow: 0 8px 30px rgba(28,34,61,.08); }
    h1 { margin-top: 0; }
    .ok { display: inline-block; padding: .25rem .6rem; border-radius: 999px; background: #dcfce7; color: #166534; font-weight: 600; }
    table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
    th, td { text-align: left; padding: .6rem; border-bottom: 1px solid #e5e7eb; vertical-align: top; }
    th { background: #f9fafb; }
    code { background: #eef2ff; padding: .1rem .35rem; border-radius: 4px; }
    a { color: #4f46e5; }
    .note { margin-top: 1.5rem; padding: 1rem; background: #eef2ff; border-radius: 8px; }
  </style>
</head>
<body>
  <main>
    <h1>ClassMate API <span class="ok">running</span></h1>
    <p>The backend is up. This URL is the API server, not the app UI.</p>
    <p>
      <a href="/api">API information (JSON)</a> ·
      <a href="/api/health">Health check</a> ·
      <a href="http://127.0.0.1:8080">Open the ClassMate app</a>
    </p>
    <table>
      <thead><tr><th>Method</th><th>URL</th><th>Description</th></tr></thead>
      <tbody>${rows}</tbody>
    </table>
    <p class="note">
      The Flutter client runs at <strong>http://127.0.0.1:8080</strong> when started with
      <code>flutter run -d chrome --web-port 8080</code>.
      Requests that change data use JSON bodies.
    </p>
  </main>
</body>
</html>`);
});

// JSON landing page: http://localhost:3000/api
app.get('/api', (req, res) => {
  res.json({
    status: 'ok',
    service: 'classmate-api',
    message: 'ClassMate API is running. This is the API root, not the app UI.',
    client: 'http://127.0.0.1:8080',
    health: '/api/health',
    endpoints: API_ENDPOINTS,
    time: new Date().toISOString(),
  });
});

app.get(
  '/api/health',
  asyncHandler(async (req, res) => {
    try {
      await db.query('SELECT 1');
    } catch (error) {
      console.error('Health check failed:', error.message);
      return res.status(503).json({
        status: 'error',
        service: 'classmate-api',
        database: 'unavailable',
        time: new Date().toISOString(),
      });
    }

    return res.json({
      status: 'ok',
      service: 'classmate-api',
      database: 'ok',
      time: new Date().toISOString(),
    });
  }),
);

app.use('/api/auth', authRoutes);
app.use('/api/subjects', subjectRoutes);
app.use('/api/schedule', scheduleRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/works', workRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/notes', noteRoutes);
app.use('/api/study', studyRoutes);
app.use('/api/grades', gradeRoutes);
app.use('/api/attachments', attachmentRoutes);
app.use('/api/recycle-bin', recycleBinRoutes);

// SPA fallback for v2 web frontend (non-API GET requests)
app.get(/^(?!\/api).*/, (req, res, next) => {
  if (req.method !== 'GET') return next();
  const indexFile = path.join(publicPath, 'index.html');
  if (fs.existsSync(indexFile)) return res.sendFile(indexFile);
  return next();
});

app.use(notFound);
app.use(errorHandler);

module.exports = app;
