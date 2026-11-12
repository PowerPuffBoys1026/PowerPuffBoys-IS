const path = require('node:path');
const fs = require('node:fs');
const express = require('express');
const cors = require('cors');

require('./db'); // initialise schema on startup
const { notFound, errorHandler } = require('./middleware/error');
const authRoutes = require('./routes/auth');
const subjectRoutes = require('./routes/subjects');
const scheduleRoutes = require('./routes/schedule');
const attendanceRoutes = require('./routes/attendance');
const workRoutes = require('./routes/works');
const dashboardRoutes = require('./routes/dashboard');
const studyRoutes = require('./routes/study');
const gradeRoutes = require('./routes/grades');
const noteRoutes = require('./routes/notes');
const recycleBinRoutes = require('./routes/recycle_bin');
const attachmentRoutes = require('./routes/attachments');

const app = express();

app.use(cors());
app.use(express.json());

// Serve web client directly from server root (public app takes priority)
const publicPath = path.resolve(__dirname, '../public');

if (fs.existsSync(publicPath)) {
  app.use(express.static(publicPath));
}

app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'classmate-api',
    version: '2.0.0',
    features: ['auth', 'subjects', 'schedule', 'attendance', 'works', 'dashboard', 'study', 'grades', 'notes', 'attachments', 'recycle-bin'],
    time: new Date().toISOString(),
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/subjects', subjectRoutes);
app.use('/api/schedule', scheduleRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/works', workRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/study', studyRoutes);
app.use('/api/grades', gradeRoutes);
app.use('/api/notes', noteRoutes);
app.use('/api/attachments', attachmentRoutes);
app.use('/api/recycle-bin', recycleBinRoutes);

// Fallback for SPA routing
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api')) return next();
  if (fs.existsSync(path.join(publicPath, 'index.html'))) {
    return res.sendFile(path.join(publicPath, 'index.html'));
  }
  next();
});

app.use(notFound);
app.use(errorHandler);

module.exports = app;
