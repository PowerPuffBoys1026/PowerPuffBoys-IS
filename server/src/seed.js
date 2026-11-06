/**
 * Development seed data. Safe to re-run: it only inserts when missing.
 *   npm run seed
 */
const bcrypt = require('bcryptjs');
const db = require('./db');

const email = (process.env.SEED_EMAIL || 'demo@classmate.app').toLowerCase();
const password = process.env.SEED_PASSWORD || 'demo12345';

async function main() {
  if (typeof db.initDb === 'function') {
    await db.initDb();
  }

  let userRes = await db.query('SELECT * FROM users WHERE email = $1', [email]);
  let user = userRes.rows[0];
  if (!user) {
    const insertRes = await db.query(
      'INSERT INTO users (email, password_hash, full_name, student_no, course) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [email, bcrypt.hashSync(password, 10), 'Demo Student', '2026-00001', 'BS Computer Science'],
    );
    user = insertRes.rows[0];
    console.log(`Created demo user: ${email} / ${password}`);
  } else {
    console.log(`Demo user already exists: ${email}`);
  }

  const existingRes = await db.query('SELECT COUNT(*) AS n FROM subjects WHERE user_id = $1', [user.id]);
  const existing = Number(existingRes.rows[0].n);
  if (existing > 0) {
    console.log('Demo subjects already exist - skipping subject/schedule/work seed.');
    await db.end();
    return;
  }

  const subjects = [
    { code: 'CS101', title: 'Intro to Computing', instructor: 'Ms. Cruz', units: 3, color: '#4F46E5' },
    { code: 'MATH201', title: 'Discrete Mathematics', instructor: 'Mr. Reyes', units: 3, color: '#0EA5E9' },
    { code: 'PE102', title: 'Physical Education 2', instructor: 'Coach Lim', units: 2, color: '#10B981' },
  ];

  const ids = [];
  for (const s of subjects) {
    const r = await db.query(
      'INSERT INTO subjects (user_id, code, title, instructor, units, color) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id',
      [user.id, s.code, s.title, s.instructor, s.units, s.color],
    );
    ids.push(r.rows[0].id);
  }

  // Monday = 1, Wednesday = 3, Friday = 5
  await db.query(
    'INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time, room, modality) VALUES ($1,$2,$3,$4,$5,$6),($7,$8,$9,$10,$11,$12),($13,$14,$15,$16,$17,$18),($19,$20,$21,$22,$23,$24),($25,$26,$27,$28,$29,$30)',
    [
      ids[0], 1, '08:00', '09:30', 'Lab 2', 'face-to-face',
      ids[0], 3, '08:00', '09:30', 'Lab 2', 'face-to-face',
      ids[1], 1, '10:00', '11:30', 'Room 305', 'face-to-face',
      ids[1], 5, '10:00', '11:30', 'Room 305', 'online',
      ids[2], 5, '13:00', '14:30', 'Gym', 'face-to-face',
    ],
  );

  const iso = (days) => new Date(Date.now() + days * 86400000).toISOString();
  await db.query(
    'INSERT INTO school_works (user_id, subject_id, title, type, due_at, priority, status, notes) VALUES ($1,$2,$3,$4,$5,$6,$7,$8),($9,$10,$11,$12,$13,$14,$15,$16),($17,$18,$19,$20,$21,$22,$23,$24),($25,$26,$27,$28,$29,$30,$31,$32)',
    [
      user.id, ids[0], 'Lab exercise 1', 'assignment', iso(2), 'high', 'todo', 'Submit via the portal',
      user.id, ids[1], 'Problem set 3', 'assignment', iso(5), 'medium', 'doing', null,
      user.id, ids[1], 'Long quiz', 'quiz', iso(9), 'high', 'todo', 'Covers chapters 4-6',
      user.id, ids[0], 'Group project proposal', 'project', iso(14), 'low', 'todo', null,
    ],
  );

  console.log(`Seeded ${subjects.length} subjects, 5 schedule slots, 4 school works.`);
  await db.end();
}

main().catch(async (err) => {
  console.error(err);
  try {
    await db.end();
  } catch (e) {}
  process.exit(1);
});
