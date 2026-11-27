/**
 * Database integrity tests. Each run creates a throwaway PostgreSQL database,
 * applies every migration, then checks the constraints and cascades the API
 * relies on. Application data is never touched.
 */
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

process.env.JWT_SECRET ||= 'test-secret';
process.env.APP_TIMEZONE ||= 'Asia/Manila';

const test = require('node:test');
const assert = require('node:assert/strict');
const { Client } = require('pg');

const testDatabase = `classmate_integrity_${process.pid}_${Date.now()}`;
let maintenance;
let db;
let created = false;

let userA;
let userB;
let subjectA;
let slotA;
let workA;
let noteA;

async function insertUser(email) {
  const { rows } = await db.query(
    `INSERT INTO users (email, password_hash, full_name)
     VALUES ($1, 'test-hash', 'Integrity Test') RETURNING id`,
    [email],
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
  userA = await insertUser(`a+${unique}@example.com`);
  userB = await insertUser(`b+${unique}@example.com`);

  const subject = await db.query(
    `INSERT INTO subjects (user_id, code, title) VALUES ($1, 'CS101', 'Intro') RETURNING id`,
    [userA],
  );
  subjectA = subject.rows[0].id;

  const slot = await db.query(
    `INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time)
     VALUES ($1, 1, '08:00', '09:00') RETURNING id`,
    [subjectA],
  );
  slotA = slot.rows[0].id;

  await db.query(
    `INSERT INTO attendance_records (subject_id, date, status)
     VALUES ($1, '2026-11-10', 'present'), ($1, '2026-11-11', 'absent')`,
    [subjectA],
  );

  const work = await db.query(
    `INSERT INTO school_works (user_id, subject_id, title) VALUES ($1, $2, 'Task') RETURNING id`,
    [userA, subjectA],
  );
  workA = work.rows[0].id;

  const note = await db.query(
    `INSERT INTO notes (user_id, subject_id, title, content) VALUES ($1, $2, 'Note', '') RETURNING id`,
    [userA, subjectA],
  );
  noteA = note.rows[0].id;
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

test('all migrations including the mobile indexes are recorded', async () => {
  const { rows } = await db.query('SELECT name FROM schema_migrations ORDER BY name');
  const names = rows.map((row) => row.name);
  for (const file of [
    '001_initial_schema.sql',
    '002_native_types.sql',
    '003_constraints_and_indexes.sql',
    '004_v2_features.sql',
    '005_stored_procedures.sql',
    '006_mobile_query_indexes.sql',
  ]) {
    assert.ok(names.includes(file), `${file} should be applied`);
  }

  const indexes = await db.query(
    `SELECT indexname FROM pg_indexes
      WHERE schemaname = current_schema() AND indexname = ANY($1::text[])`,
    [['idx_attendance_date', 'idx_slots_day_of_week', 'idx_works_user_status_due']],
  );
  assert.equal(indexes.rows.length, 3);
});

test('subject codes are unique per user, not globally', async () => {
  await assert.rejects(
    db.query(`INSERT INTO subjects (user_id, code, title) VALUES ($1, 'CS101', 'Duplicate')`, [userA]),
    (error) => error.code === '23505',
  );

  const other = await db.query(
    `INSERT INTO subjects (user_id, code, title) VALUES ($1, 'CS101', 'Other owner') RETURNING id`,
    [userB],
  );
  assert.ok(other.rows[0].id);
});

test('attendance status and time ranges are constrained in the database', async () => {
  await assert.rejects(
    db.query(
      `INSERT INTO attendance_records (subject_id, date, status) VALUES ($1, '2026-11-12', 'maybe')`,
      [subjectA],
    ),
    (error) => error.code === '23514',
  );

  await assert.rejects(
    db.query(
      `INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time)
       VALUES ($1, 2, '10:00', '09:00')`,
      [subjectA],
    ),
    (error) => error.code === '23514',
  );
});

test('one attendance record per subject/date/slot is enforced', async () => {
  await assert.rejects(
    db.query(
      `INSERT INTO attendance_records (subject_id, date, status) VALUES ($1, '2026-11-10', 'late')`,
      [subjectA],
    ),
    (error) => error.code === '23505',
  );

  await db.query(
    `INSERT INTO attendance_records (subject_id, slot_id, date, status)
     VALUES ($1, $2, '2026-11-10', 'present')`,
    [subjectA, slotA],
  );
  await assert.rejects(
    db.query(
      `INSERT INTO attendance_records (subject_id, slot_id, date, status)
       VALUES ($1, $2, '2026-11-10', 'absent')`,
      [subjectA, slotA],
    ),
    (error) => error.code === '23505',
  );
});

test('foreign keys prevent orphaned rows', async () => {
  await assert.rejects(
    db.query(
      `INSERT INTO attendance_records (subject_id, date, status) VALUES (999999, '2026-11-10', 'present')`,
    ),
    (error) => error.code === '23503',
  );
  await assert.rejects(
    db.query(
      `INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time)
       VALUES (999999, 1, '08:00', '09:00')`,
    ),
    (error) => error.code === '23503',
  );
});

test('deleting a subject cascades sessions and keeps optional links safe', async () => {
  await db.query('DELETE FROM subjects WHERE id = $1', [subjectA]);

  const attendance = await db.query(
    'SELECT id FROM attendance_records WHERE subject_id = $1',
    [subjectA],
  );
  assert.equal(attendance.rows.length, 0, 'attendance records should cascade');

  const slots = await db.query('SELECT id FROM schedule_slots WHERE id = $1', [slotA]);
  assert.equal(slots.rows.length, 0, 'schedule slots should cascade');

  const work = await db.query('SELECT subject_id FROM school_works WHERE id = $1', [workA]);
  assert.equal(work.rows[0].subject_id, null, 'a work keeps its row and loses the subject link');

  const note = await db.query('SELECT subject_id FROM notes WHERE id = $1', [noteA]);
  assert.equal(note.rows[0].subject_id, null, 'a note keeps its row and loses the subject link');
});
