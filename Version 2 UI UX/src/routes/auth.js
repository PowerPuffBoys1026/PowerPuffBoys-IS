const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { z } = require('zod');

const db = require('../db');
const config = require('../config');
const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  fullName: z.string().min(1, 'Full name is required'),
  studentNo: z.string().optional(),
  yearLevel: z.string().optional(),
  course: z.string().optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1, 'Password is required'),
});

const profileUpdateSchema = z.object({
  fullName: z.string().trim().min(1, 'Full name is required'),
  studentNo: z.string().trim().nullish(),
  course: z.string().trim().nullish(),
  yearLevel: z.string().trim().nullish(),
});

const passwordUpdateSchema = z.object({
  currentPassword: z.string().min(1, 'Current password is required'),
  newPassword: z.string().min(8, 'New password must be at least 8 characters'),
});

function publicUser(row) {
  return {
    id: row.id,
    email: row.email,
    fullName: row.full_name,
    studentNo: row.student_no,
    course: row.course,
    yearLevel: row.year_level,
    createdAt: row.created_at,
  };
}

function signToken(user) {
  return jwt.sign({ sub: String(user.id) }, config.jwtSecret, { expiresIn: config.jwtExpiresIn });
}

// POST /api/auth/register
router.post('/register', (req, res) => {
  const data = validate(registerSchema, req.body);
  const email = data.email.toLowerCase();

  if (db.prepare('SELECT id FROM users WHERE email = ?').get(email)) {
    throw new HttpError(409, 'Email is already registered');
  }

  const hash = bcrypt.hashSync(data.password, 10);
  const info = db
    .prepare(
      'INSERT INTO users (email, password_hash, full_name, student_no, course, year_level) VALUES (?, ?, ?, ?, ?, ?)',
    )
    .run(email, hash, data.fullName, data.studentNo ?? null, data.course ?? null, data.yearLevel ?? null);

  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(info.lastInsertRowid);
  res.status(201).json({ token: signToken(user), user: publicUser(user) });
});

// POST /api/auth/login
router.post('/login', (req, res) => {
  const data = validate(loginSchema, req.body);
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(data.email.toLowerCase());

  if (!user || !bcrypt.compareSync(data.password, user.password_hash)) {
    throw new HttpError(401, 'Invalid email or password');
  }

  res.json({ token: signToken(user), user: publicUser(user) });
});

// GET /api/auth/me
router.get('/me', requireAuth, (req, res) => {
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.userId);
  if (!user) throw new HttpError(404, 'User not found');
  res.json({ data: publicUser(user) });
});

router.put('/me', requireAuth, (req, res) => {
  const data = validate(profileUpdateSchema, req.body);
  db.prepare('UPDATE users SET full_name = ?, student_no = ?, course = ?, year_level = ? WHERE id = ?').run(
    data.fullName,
    data.studentNo || null,
    data.course || null,
    data.yearLevel || null,
    req.userId,
  );
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.userId);
  if (!user) throw new HttpError(404, 'User not found');
  res.json({ data: publicUser(user) });
});

router.put('/me/password', requireAuth, (req, res) => {
  const data = validate(passwordUpdateSchema, req.body);
  const user = db.prepare('SELECT password_hash FROM users WHERE id = ?').get(req.userId);
  if (!user) throw new HttpError(404, 'User not found');
  if (!bcrypt.compareSync(data.currentPassword, user.password_hash)) {
    throw new HttpError(400, 'Current password is incorrect');
  }

  const passwordHash = bcrypt.hashSync(data.newPassword, 10);
  db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(passwordHash, req.userId);
  res.json({ data: { success: true } });
});

module.exports = router;
