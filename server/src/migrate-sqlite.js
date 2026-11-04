const path = require('node:path');
const Database = require('better-sqlite3');
const db = require('./db');

const sqliteFile = path.join(__dirname, '..', 'data', 'classmate.db');
const tables = [
  {
    name: 'users',
    columns: ['id', 'email', 'password_hash', 'full_name', 'student_no', 'course', 'created_at'],
  },
  {
    name: 'subjects',
    columns: ['id', 'user_id', 'code', 'title', 'instructor', 'units', 'color', 'created_at'],
  },
  {
    name: 'schedule_slots',
    columns: ['id', 'subject_id', 'day_of_week', 'start_time', 'end_time', 'room', 'modality'],
  },
  {
    name: 'attendance_records',
    columns: ['id', 'subject_id', 'slot_id', 'date', 'status', 'note', 'created_at'],
  },
  {
    name: 'school_works',
    columns: [
      'id', 'user_id', 'subject_id', 'title', 'type', 'due_at', 'priority', 'status',
      'notes', 'created_at', 'updated_at',
    ],
  },
  {
    name: 'notes',
    columns: [
      'id', 'user_id', 'title', 'content', 'is_pinned', 'color', 'tags', 'created_at', 'updated_at',
    ],
  },
];

async function main() {
  const sqlite = new Database(sqliteFile, { readonly: true, fileMustExist: true });
  let client;
  let transactionStarted = false;
  try {
    await db.initDb();
    client = await db.connect();
    const counts = {};
    for (const table of tables) {
      const { rows } = await client.query(`SELECT COUNT(*)::int AS count FROM ${table.name}`);
      counts[table.name] = rows[0].count;
    }

    const populated = Object.entries(counts).filter(([, count]) => count > 0);
    if (populated.length) {
      throw new Error(
        `Refusing to import into a non-empty PostgreSQL database (${populated.map(([name]) => name).join(', ')}).`,
      );
    }

    await client.query('BEGIN');
    transactionStarted = true;
    let total = 0;
    for (const table of tables) {
      const rows = sqlite.prepare(`SELECT ${table.columns.join(', ')} FROM ${table.name}`).all();
      const placeholders = table.columns.map((_, index) => `$${index + 1}`).join(', ');
      const sql = `INSERT INTO ${table.name} (${table.columns.join(', ')}) VALUES (${placeholders})`;

      for (const row of rows) {
        const values = table.columns.map((column) => {
          if (table.name === 'notes' && column === 'is_pinned') return Boolean(row[column]);
          return row[column];
        });
        await client.query(sql, values);
      }

      if (rows.length) {
        await client.query(
          `SELECT setval(pg_get_serial_sequence('${table.name}', 'id'), (SELECT MAX(id) FROM ${table.name}), TRUE)`,
        );
      }
      total += rows.length;
      console.log(`Imported ${rows.length} ${table.name}.`);
    }

    await client.query('COMMIT');
    transactionStarted = false;
    console.log(`SQLite import complete: ${total} rows. The SQLite file was left unchanged.`);
  } catch (error) {
    if (transactionStarted) await client.query('ROLLBACK');
    throw error;
  } finally {
    sqlite.close();
    if (client) client.release();
    await db.end();
  }
}

main().catch((error) => {
  console.error('SQLite import failed:', error.message);
  process.exitCode = 1;
});
