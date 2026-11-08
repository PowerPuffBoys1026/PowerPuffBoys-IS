require('dotenv').config();

const path = require('node:path');

const config = {
  port: Number(process.env.PORT) || 3000,
  jwtSecret: process.env.JWT_SECRET || 'dev-secret-change-me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  dbFile: process.env.DB_FILE
    ? path.resolve(process.cwd(), process.env.DB_FILE)
    : path.join(__dirname, '..', 'data', 'classmate.db'),
  attendanceThreshold: Number(process.env.ATTENDANCE_THRESHOLD) || 20,
};

module.exports = config;
