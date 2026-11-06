const fs = require('node:fs');
const path = require('node:path');

const MIGRATIONS_DIR = path.join(__dirname, '..', 'migrations');
const MIGRATION_LOCK_ID = 727271001;

/**
 * Apply every `.sql` file in `migrations/` that has not run yet.
 *
 * A session-level advisory lock prevents two API instances from migrating at
 * the same time. Each file runs inside its own transaction and is recorded in
 * `schema_migrations`, so a failed migration is rolled back and can be retried.
 */
async function runMigrations(pool, { log = () => {} } = {}) {
  const client = await pool.connect();
  try {
    await client.query('SELECT pg_advisory_lock($1)', [MIGRATION_LOCK_ID]);

    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name       TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    const files = fs
      .readdirSync(MIGRATIONS_DIR)
      .filter((file) => file.endsWith('.sql'))
      .sort();

    const { rows } = await client.query('SELECT name FROM schema_migrations');
    const applied = new Set(rows.map((row) => row.name));

    let count = 0;
    for (const file of files) {
      if (applied.has(file)) continue;

      const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
      await client.query('BEGIN');
      try {
        // Migrations may take longer than the API's per-query timeout.
        await client.query('SET LOCAL statement_timeout = 0');
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw new Error(`Migration ${file} failed: ${error.message}`, { cause: error });
      }

      count += 1;
      log(`Applied migration ${file}`);
    }

    return count;
  } finally {
    try {
      await client.query('SELECT pg_advisory_unlock($1)', [MIGRATION_LOCK_ID]);
    } catch {}
    client.release();
  }
}

module.exports = { runMigrations, MIGRATIONS_DIR };

if (require.main === module) {
  const db = require('./db');

  runMigrations(db, { log: console.log })
    .then(async (count) => {
      console.log(count ? `Migrations complete (${count} applied).` : 'Database is up to date.');
      await db.end();
    })
    .catch(async (error) => {
      console.error(error);
      try {
        await db.end();
      } catch {}
      process.exitCode = 1;
    });
}
