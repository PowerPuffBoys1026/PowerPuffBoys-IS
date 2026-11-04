require('dotenv').config();

const config = {
  port: Number(process.env.PORT) || 3000,
  jwtSecret: process.env.JWT_SECRET || 'dev-secret-change-me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
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
