/**
 * Create the local PostgreSQL database (if it does not exist) and apply
 * db/schema.sql.
 *
 *   npm run db:init
 *
 * Reads DATABASE_URL from .env (or the process environment). The database
 * name is taken from the URL path, e.g.
 *   postgres://postgres:secret@localhost:5432/classmate  ->  classmate
 */
const { Client } = require('pg');
const config = require('../src/config');

function targetDatabase() {
  const url = new URL(config.databaseUrl);
  const name = decodeURIComponent(url.pathname.replace(/^\/+/, ''));

  if (!name) {
    throw new Error('DATABASE_URL must include a database name, e.g. .../classmate');
  }
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(name)) {
    throw new Error(`Invalid database name: ${name}`);
  }

  return { url, name };
}

async function ensureDatabase() {
  const { url, name } = targetDatabase();

  // Connect to the standard maintenance database to create the app database.
  const maintenanceUrl = new URL(url.toString());
  maintenanceUrl.pathname = '/postgres';

  const client = new Client({
    connectionString: maintenanceUrl.toString(),
    ssl: config.databaseSsl ? { rejectUnauthorized: false } : false,
  });

  await client.connect();
  try {
    const { rowCount } = await client.query(
      'SELECT 1 FROM pg_database WHERE datname = $1',
      [name],
    );

    if (rowCount === 0) {
      await client.query(`CREATE DATABASE "${name}"`);
      console.log(`Created database "${name}".`);
    } else {
      console.log(`Database "${name}" already exists.`);
    }
  } finally {
    await client.end();
  }
}

async function main() {
  await ensureDatabase();

  // Requiring db.js after the database exists ensures the pool can connect.
  const { init, close } = require('../src/db');
  try {
    await init();
    const where = config.dbSchema === 'public' ? 'public schema' : `schema "${config.dbSchema}"`;
    console.log(`Applied db/schema.sql to the ${where}.`);
  } finally {
    await close();
  }
}

main().catch((err) => {
  console.error('Database initialisation failed.');
  console.error(err.message);
  process.exit(1);
});
