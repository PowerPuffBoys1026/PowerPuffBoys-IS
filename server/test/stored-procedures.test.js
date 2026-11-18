/**
 * Database routine tests for migration 005.
 *
 * Like api.test.js, this creates a throwaway PostgreSQL database so neither
 * local application data nor CI data is touched. The routines are tested at
 * the database layer: the Node API does not call them yet.
 */
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

process.env.JWT_SECRET ||= 'test-secret';
process.env.APP_TIMEZONE ||= 'Asia/Manila';

const test = require('node:test');
const assert = require('node:assert/strict');
const { Client } = require('pg');

const testDatabase = `classmate_routines_${process.pid}_${Date.now()}`;
let maintenance;
let db;
let created = false;

let ownerId;
let otherId;
let subjectId;
let otherSubjectId;
let slotId;
let workId;
let otherWorkId;

async function insertUser(email) {
  const { rows } = await db.query(
    `INSERT INTO users (email, password_hash, full_name)
     VALUES ($1, 'test-hash', 'Routine Test') RETURNING id`,
    [email],
  );
  return rows[0].id;
}

async function insertSubject(userId, code) {
  const { rows } = await db.query(
    `INSERT INTO subjects (user_id, code, title) VALUES ($1, $2, $3) RETURNING id`,
    [userId, code, `${code} title`],
  );
  return rows[0].id;
}

test.before(async () => {
  maintenance = new Client({
    host: process.env.PGHOST || 'localhost',
    port: Number(process.env.PGPORT) || 5432,
    database: process.env.PGMAINTENANCE_DB || 'postgres',
    user: process.env.PGUSER || 'postgres',
    password: process.env.PGPASSWORD,
  });
  await maintenance.connect();
  await maintenance.query(`CREATE DATABASE "${testDatabase}"`);
  created = true;

  process.env.PGDATABASE = testDatabase;
  db = require('../src/db');
  await db.initDb();

  const unique = `${process.pid}_${Date.now()}`;
  ownerId = await insertUser(`owner+${unique}@example.com`);
  otherId = await insertUser(`other+${unique}@example.com`);
  subjectId = await insertSubject(ownerId, 'CS101');
  otherSubjectId = await insertSubject(otherId, 'CS999');

  await db.query(
    `INSERT INTO attendance_records (subject_id, date, status) VALUES
       ($1, '2026-11-10', 'present'),
       ($1, '2026-11-11', 'present'),
       ($1, '2026-11-12', 'absent'),
       ($1, '2026-11-13', 'late'),
       ($1, '2026-11-14', 'cancelled')`,
    [subjectId],
  );

  const slot = await db.query(
    `INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time)
     VALUES ($1, 1, '09:00', '10:30'), ($1, 1, '07:30', '08:30')
     RETURNING id, start_time`,
    [subjectId],
  );
  slotId = slot.rows.find((row) => row.start_time === '09:00').id;

  const work = await db.query(
    `INSERT INTO school_works (user_id, subject_id, title, due_at, status) VALUES
       ($1, $2, 'Due soon', '2026-11-20T09:00:00Z', 'todo'),
       ($1, $2, 'Later', '2026-12-01T09:00:00Z', 'todo'),
       ($1, $2, 'Finished', '2026-11-19T09:00:00Z', 'done')
     RETURNING id, title`,
    [ownerId, subjectId],
  );
  workId = work.rows.find((row) => row.title === 'Due soon').id;

  const otherWork = await db.query(
    `INSERT INTO school_works (user_id, subject_id, title, due_at, status)
     VALUES ($1, $2, 'Another user', '2026-11-20T09:00:00Z', 'todo')
     RETURNING id`,
    [otherId, otherSubjectId],
  );
  otherWorkId = otherWork.rows[0].id;
});

test.after(async () => {
  if (db) await db.end();
  if (created) {
    await maintenance.query(
      'SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = $1 AND pid <> pg_backend_pid()',
      [testDatabase],
    );
    await maintenance.query(`DROP DATABASE "${testDatabase}"`);
  }
  if (maintenance) await maintenance.end();
});

test('get_attendance_summary computes counts, rates and warnings', async () => {
  const { rows } = await db.query(
    'SELECT * FROM get_attendance_summary($1, $2)',
    [ownerId, 20],
  );

  const withRecords = rows.find((row) => row.subject_id === subjectId);
  assert.equal(withRecords.present, 2);
  assert.equal(withRecords.absent, 1);
  assert.equal(withRecords.late, 1);
  assert.equal(withRecords.cancelled, 1);
  assert.equal(withRecords.counted, 4);
  assert.equal(Number(withRecords.attendance_rate), 50);
  assert.equal(Number(withRecords.absence_rate), 25);
  assert.equal(withRecords.safe_misses_left, 4); // 28 * 20% = 5 allowed - 1 absence
  assert.equal(withRecords.health_status, 'warning');
  assert.equal(withRecords.warning, true);

  const empty = rows.find((row) => row.subject_id === otherSubjectId);
  assert.equal(empty, undefined, 'routines must scope rows to the given user');

  const emptySubject = await db.query(
    `INSERT INTO subjects (user_id, code, title) VALUES ($1, 'EMPTY', 'Empty') RETURNING id`,
    [ownerId],
  );
  const emptySummary = await db.query(
    'SELECT * FROM get_attendance_summary($1, $2) WHERE subject_id = $3',
    [ownerId, 20, emptySubject.rows[0].id],
  );
  assert.equal(emptySummary.rows[0].counted, 0);
  assert.equal(emptySummary.rows[0].attendance_rate, null);
  assert.equal(emptySummary.rows[0].warning, false);
});

test('get_dashboard_classes returns the user slots in time order', async () => {
  const { rows } = await db.query(
    'SELECT * FROM get_dashboard_classes($1, $2)',
    [ownerId, 1],
  );
  assert.equal(rows.length, 2);
  // db.js parses PostgreSQL TIME values as HH:MM for the API contract.
  assert.equal(rows[0].start_time, '07:30');
  assert.equal(rows[1].start_time, '09:00');
  assert.equal(rows[0].code, 'CS101');

  const other = await db.query(
    'SELECT * FROM get_dashboard_classes($1, $2)',
    [otherId, 1],
  );
  assert.equal(other.rows.length, 0);
});

test('get_due_soon_works excludes done and far-future works', async () => {
  const { rows } = await db.query(
    'SELECT * FROM get_due_soon_works($1, $2, $3)',
    [ownerId, '2026-11-18', 7],
  );
  assert.deepEqual(rows.map((row) => row.title), ['Due soon']);
  assert.equal(rows[0].work_id, workId);
});

test('mark_attendance inserts or updates after checking ownership', async () => {
  const created = await db.query(
    `CALL mark_attendance($1, $2, $3, $4, $5, $6, NULL, NULL)`,
    [ownerId, subjectId, slotId, '2026-11-18', 'present', 'first save'],
  );
  const createdId = created.rows[0].p_attendance_id;
  assert.ok(createdId);
  assert.equal(created.rows[0].p_was_created, true);

  const updated = await db.query(
    `CALL mark_attendance($1, $2, $3, $4, $5, $6, NULL, NULL)`,
    [ownerId, subjectId, slotId, '2026-11-18', 'absent', 'corrected'],
  );
  assert.equal(updated.rows[0].p_attendance_id, createdId);
  assert.equal(updated.rows[0].p_was_created, false);

  const saved = await db.query(
    'SELECT status, note FROM attendance_records WHERE id = $1',
    [createdId],
  );
  assert.equal(saved.rows[0].status, 'absent');
  assert.equal(saved.rows[0].note, 'corrected');

  await assert.rejects(
    db.query(
      `CALL mark_attendance($1, $2, NULL, $3, $4, NULL, NULL, NULL)`,
      [ownerId, otherSubjectId, '2026-11-18', 'present'],
    ),
    (error) => error.code === 'P0002',
  );
});

test('set_work_status updates only works owned by the caller', async () => {
  const result = await db.query(
    'CALL set_work_status($1, $2, $3, NULL)',
    [ownerId, workId, 'done'],
  );
  assert.equal(result.rows[0].p_updated_id, workId);

  const saved = await db.query('SELECT status FROM school_works WHERE id = $1', [workId]);
  assert.equal(saved.rows[0].status, 'done');

  await assert.rejects(
    db.query('CALL set_work_status($1, $2, $3, NULL)', [ownerId, otherWorkId, 'done']),
    (error) => error.code === 'P0002',
  );
});

test('routines reject invalid input with SQLSTATE 22023', async () => {
  await assert.rejects(
    db.query('SELECT * FROM get_dashboard_classes($1, $2)', [ownerId, 9]),
    (error) => error.code === '22023',
  );
  await assert.rejects(
    db.query('CALL set_work_status($1, $2, $3, NULL)', [ownerId, workId, 'unknown']),
    (error) => error.code === '22023',
  );
});
