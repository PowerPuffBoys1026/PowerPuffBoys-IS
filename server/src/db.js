const { Pool, types } = require('pg');
const config = require('./config');
const { runMigrations } = require('./migrate');

// Return DATE values as `YYYY-MM-DD` strings instead of JS Dates, which would
// otherwise shift across time zones. Render TIME values as `HH:MM` to keep the
// API contract stable after the column-type migration.
types.setTypeParser(1082, (value) => value);
types.setTypeParser(1083, (value) => value.slice(0, 5));

const pool = new Pool({
  ...(config.databaseUrl
    ? { connectionString: config.databaseUrl }
    : {
        host: config.pgHost,
        port: config.pgPort,
        database: config.pgDatabase,
        user: config.pgUser,
        password: config.pgPassword,
      }),
  max: config.pgPoolMax,
  connectionTimeoutMillis: config.pgConnectTimeoutMs,
  idleTimeoutMillis: 30000,
  statement_timeout: config.pgStatementTimeoutMs,
  application_name: 'classmate-api',
  // Keep date casts and boundary comparisons aligned with APP_TIMEZONE.
  options: `-c timezone=${config.appTimezone}`,
});

pool.on('error', (error) => {
  console.error('Unexpected PostgreSQL pool error:', error.message);
});

/** Apply pending migrations. */
async function initDb() {
  return runMigrations(pool);
}

pool.initDb = initDb;
pool.migrate = initDb;

module.exports = pool;
