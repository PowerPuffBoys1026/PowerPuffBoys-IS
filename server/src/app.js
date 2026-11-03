const express = require('express');
const cors = require('cors');

const { init } = require('./db');
const { notFound, errorHandler } = require('./middleware/error');
const authRoutes = require('./routes/auth');
const subjectRoutes = require('./routes/subjects');
const scheduleRoutes = require('./routes/schedule');
const attendanceRoutes = require('./routes/attendance');
const workRoutes = require('./routes/works');
const dashboardRoutes = require('./routes/dashboard');
const noteRoutes = require('./routes/notes');

// Start creating the Postgres schema as soon as the app is loaded. Every
// request waits for this to finish before touching the database.
const ready = init();

const app = express();

app.use(cors());
app.use(express.json());

app.use(async (req, res, next) => {
  try {
    await ready;
    next();
  } catch (err) {
    next(err);
  }
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', service: 'classmate-api', time: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/subjects', subjectRoutes);
app.use('/api/schedule', scheduleRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/works', workRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/notes', noteRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
