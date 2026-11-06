require('dotenv').config();

const DEFAULT_JWT_SECRET = 'dev-secret-change-me';

const jwtSecret = (process.env.JWT_SECRET || '').trim();
if (!jwtSecret) {
  throw new Error(
    'JWT_SECRET is required. Add a long random value to server/.env (see .env.example).',
  );
}
if (process.env.NODE_ENV === 'production' && jwtSecret === DEFAULT_JWT_SECRET) {
  throw new Error('JWT_SECRET must not use the example value in production.');
}

const configuredOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

const config = {
  port: Number(process.env.PORT) || 3000,
  jwtSecret,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  corsOrigins: configuredOrigins.length
    ? configuredOrigins
    : [
        'http://localhost:8080',
        'http://127.0.0.1:8080',
        'http://localhost:3000',
        'http://127.0.0.1:3000',
      ],
  databaseUrl: process.env.DATABASE_URL,
  pgHost: process.env.PGHOST || 'localhost',
  pgPort: Number(process.env.PGPORT) || 5432,
  pgDatabase: process.env.PGDATABASE || 'classmate',
  pgMaintenanceDatabase: process.env.PGMAINTENANCE_DB || 'postgres',
  pgUser: process.env.PGUSER || 'postgres',
  pgPassword: process.env.PGPASSWORD,
  attendanceThreshold: Number(process.env.ATTENDANCE_THRESHOLD) || 20,
};

module.exports = config;
