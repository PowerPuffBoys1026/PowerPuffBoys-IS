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

const appTimezone = process.env.APP_TIMEZONE || 'Asia/Manila';
try {
  new Intl.DateTimeFormat('en-US', { timeZone: appTimezone }).format();
} catch {
  throw new Error(`APP_TIMEZONE is not a valid IANA time zone: ${appTimezone}`);
}

const path = require('node:path');

const config = {
  port: Number(process.env.PORT) || 3000,
  jwtSecret,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  appTimezone,
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
  pgPoolMax: Number(process.env.PGPOOL_MAX) || 10,
  pgConnectTimeoutMs: Number(process.env.PGCONNECT_TIMEOUT_MS) || 5000,
  pgStatementTimeoutMs: Number(process.env.PGSTATEMENT_TIMEOUT_MS) || 10000,
  attendanceThreshold: Number(process.env.ATTENDANCE_THRESHOLD) || 20,
  uploadDir: process.env.UPLOAD_DIR
    ? path.resolve(process.cwd(), process.env.UPLOAD_DIR)
    : path.join(__dirname, '..', 'data', 'uploads'),
};

module.exports = config;
