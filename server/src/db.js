const fs = require('node:fs');
const path = require('node:path');
const { Pool } = require('pg');
const config = require('./config');

const SCHEMA_NAME = config.dbSchema;
if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(SCHEMA_NAME)) {
  throw new Error(`Invalid PG_SCHEMA value: ${SCHEMA_NAME}`);
}

const SCHEMA = fs.readFileSync(path.join(__dirname, '..', 'db', 'schema.sql'), 'utf8');

const poolConfig = { connectionString: config.databaseUrl };

if (config.databaseSsl) {
  poolConfig.ssl = { rejectUnauthorized: false };
}

// Keep every connection on the configured schema. The smoke test uses a
// throwaway schema so it never touches development data.
if (SCHEMA_NAME !== 'public') {
  poolConfig.options = `-c search_path="${SCHEMA_NAME}"`;
}

const pool = new Pool(poolConfig);

pool.on('error', (err) => {
  console.error('Unexpected PostgreSQL pool error', err);
});

let initPromise = null;

/** Create the configured schema and its tables once per process (idempotent). */
function init() {
  if (!initPromise) {
    initPromise = (async () => {
      if (SCHEMA_NAME !== 'public') {
        await pool.query(`CREATE SCHEMA IF NOT EXISTS "${SCHEMA_NAME}"`);
      }
      await pool.query(SCHEMA);
    })().catch((err) => {
      initPromise = null;
      throw err;
    });
  }
  return initPromise;
}

function query(text, params) {
  return pool.query(text, params);
}

function close() {
  return pool.end();
}

module.exports = { pool, query, init, close };
