/**
 * Development seed data. Safe to re-run: it only inserts when missing.
 *   npm run seed
 */
const bcrypt = require('bcryptjs');
const { init, query, close } = require('./db');

const email = (process.env.SEED_EMAIL || 'demo@classmate.app').toLowerCase();
const password = process.env.SEED_PASSWORD || 'demo12345';

async function main() {
  await init();

  const { rows: userRows } = await query('SELECT * FROM users WHERE email = $1', [email]);
  let user = userRows[0];

  if (!user) {
    const { rows } = await query(
      `INSERT INTO users (email, password_hash, full_name, student_no, course)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [email, bcrypt.hashSync(password, 10), 'Demo Student', '2026-00001', 'BS Computer Science'],
    );
    user = rows[0];
    console.log(`Created demo user: ${email} / ${password}`);
  } else {
    console.log(`Demo user already exists: ${email}`);
  }

  const { rows: countRows } = await query(
    'SELECT COUNT(*)::int AS n FROM subjects WHERE user_id = $1',
    [user.id],
  );
  if (countRows[0].n > 0) {
    console.log('Demo subjects already exist - skipping subject/schedule/work seed.');
    return;
  }

  const subjects = [
    { code: 'CS101', title: 'Intro to Computing', instructor: 'Ms. Cruz', units: 3, color: '#4F46E5' },
    { code: 'MATH201', title: 'Discrete Mathematics', instructor: 'Mr. Reyes', units: 3, color: '#0EA5E9' },
    { code: 'PE102', title: 'Physical Education 2', instructor: 'Coach Lim', units: 2, color: '#10B981' },
  ];

  const ids = [];
  for (const s of subjects) {
    const { rows } = await query(
      `INSERT INTO subjects (user_id, code, title, instructor, units, color)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id`,
      [user.id, s.code, s.title, s.instructor, s.units, s.color],
    );
    ids.push(rows[0].id);
  }

  // Monday = 1, Wednesday = 3, Friday = 5
  const slots = [
    [ids[0], 1, '08:00', '09:30', 'Lab 2', 'face-to-face'],
    [ids[0], 3, '08:00', '09:30', 'Lab 2', 'face-to-face'],
    [ids[1], 1, '10:00', '11:30', 'Room 305', 'face-to-face'],
    [ids[1], 5, '10:00', '11:30', 'Room 305', 'online'],
    [ids[2], 5, '13:00', '14:30', 'Gym', 'face-to-face'],
  ];
  for (const slot of slots) {
    await query(
      `INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time, room, modality)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      slot,
    );
  }

  const iso = (days) => new Date(Date.now() + days * 86400000).toISOString();
  const works = [
    [ids[0], 'Lab exercise 1', 'assignment', iso(2), 'high', 'todo', 'Submit via the portal'],
    [ids[1], 'Problem set 3', 'assignment', iso(5), 'medium', 'doing', null],
    [ids[1], 'Long quiz', 'quiz', iso(9), 'high', 'todo', 'Covers chapters 4-6'],
    [ids[0], 'Group project proposal', 'project', iso(14), 'low', 'todo', null],
  ];
  for (const work of works) {
    await query(
      `INSERT INTO school_works (user_id, subject_id, title, type, due_at, priority, status, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [user.id, ...work],
    );
  }

  console.log(`Seeded ${subjects.length} subjects, ${slots.length} schedule slots, ${works.length} school works.`);
}

main()
  .then(() => close())
  .catch(async (err) => {
    console.error(err);
    await close();
    process.exit(1);
  });
