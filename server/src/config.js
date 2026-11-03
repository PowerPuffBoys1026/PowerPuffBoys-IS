require('dotenv').config();

const config = {
  port: Number(process.env.PORT) || 3000,
  jwtSecret: process.env.JWT_SECRET || 'dev-secret-change-me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  // PostgreSQL connection string, e.g. postgres://user:pass@localhost:5432/classmate
  databaseUrl:
    process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/classmate',
  // Managed Postgres providers often require SSL. Enable with DATABASE_SSL=true.
  databaseSsl: process.env.DATABASE_SSL === 'true',
  // Optional schema; defaults to public. Used by the smoke test for isolation.
  dbSchema: process.env.PG_SCHEMA || 'public',
  attendanceThreshold: Number(process.env.ATTENDANCE_THRESHOLD) || 20,
};

module.exports = config;
