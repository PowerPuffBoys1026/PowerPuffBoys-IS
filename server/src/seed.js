/**
 * Development seed data. Safe to re-run: it only inserts when missing.
 *   npm run seed
 */
const bcrypt = require('bcryptjs');
const db = require('./db');

const email = (process.env.SEED_EMAIL || 'demo@classmate.app').toLowerCase();
const password = process.env.SEED_PASSWORD || 'demo12345';

function main() {
  let user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
  if (!user) {
    const info = db
      .prepare('INSERT INTO users (email, password_hash, full_name, student_no, course) VALUES (?, ?, ?, ?, ?)')
      .run(email, bcrypt.hashSync(password, 10), 'Demo Student', '2026-00001', 'BS Computer Science');
    user = db.prepare('SELECT * FROM users WHERE id = ?').get(info.lastInsertRowid);
    console.log(`Created demo user: ${email} / ${password}`);
  } else {
    console.log(`Demo user already exists: ${email}`);
  }

  const existing = db.prepare('SELECT COUNT(*) AS n FROM subjects WHERE user_id = ?').get(user.id).n;
  if (existing > 0) {
    console.log('Demo subjects already exist - skipping subject/schedule/work seed.');
    return;
  }

  const subjects = [
    { code: 'CS101', title: 'Intro to Computing', instructor: 'Ms. Cruz', units: 3, color: '#4F46E5' },
    { code: 'MATH201', title: 'Discrete Mathematics', instructor: 'Mr. Reyes', units: 3, color: '#0EA5E9' },
    { code: 'PE102', title: 'Physical Education 2', instructor: 'Coach Lim', units: 2, color: '#10B981' },
  ];

  const insertSubject = db.prepare(
    'INSERT INTO subjects (user_id, code, title, instructor, units, color) VALUES (?, ?, ?, ?, ?, ?)',
  );
  const ids = subjects.map(
    (s) => insertSubject.run(user.id, s.code, s.title, s.instructor, s.units, s.color).lastInsertRowid,
  );

  const insertSlot = db.prepare(
    'INSERT INTO schedule_slots (subject_id, day_of_week, start_time, end_time, room, modality) VALUES (?, ?, ?, ?, ?, ?)',
  );
  // Monday = 1, Wednesday = 3, Friday = 5
  insertSlot.run(ids[0], 1, '08:00', '09:30', 'Lab 2', 'face-to-face');
  insertSlot.run(ids[0], 3, '08:00', '09:30', 'Lab 2', 'face-to-face');
  insertSlot.run(ids[1], 1, '10:00', '11:30', 'Room 305', 'face-to-face');
  insertSlot.run(ids[1], 5, '10:00', '11:30', 'Room 305', 'online');
  insertSlot.run(ids[2], 5, '13:00', '14:30', 'Gym', 'face-to-face');

  const insertWork = db.prepare(
    'INSERT INTO school_works (user_id, subject_id, title, type, due_at, priority, status, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
  );
  const iso = (days) => new Date(Date.now() + days * 86400000).toISOString();
  insertWork.run(user.id, ids[0], 'Lab exercise 1', 'assignment', iso(2), 'high', 'todo', 'Submit via the portal');
  insertWork.run(user.id, ids[1], 'Problem set 3', 'assignment', iso(5), 'medium', 'doing', null);
  insertWork.run(user.id, ids[1], 'Long quiz', 'quiz', iso(9), 'high', 'todo', 'Covers chapters 4-6');
  insertWork.run(user.id, ids[0], 'Group project proposal', 'project', iso(14), 'low', 'todo', null);

  console.log(`Seeded ${subjects.length} subjects, 5 schedule slots, 4 school works.`);
}

main();
