const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { z } = require('zod');

const config = require('../config');
const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const UserModel = require('../models/user.model');
const { publicUser } = require('../views/user.view');

const registerSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z
    .string()
    .min(8, 'Password must be at least 8 characters')
    .max(72, 'Password must be at most 72 characters'),
  fullName: z.string().trim().min(1, 'Full name is required').max(120),
  studentNo: z.string().trim().max(40).optional(),
  course: z.string().trim().max(120).optional(),
});

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1, 'Password is required').max(72),
});

function signToken(user) {
  return jwt.sign({ sub: String(user.id) }, config.jwtSecret, { expiresIn: config.jwtExpiresIn });
}

const AuthController = {
  register: async (req, res) => {
    const data = validate(registerSchema, req.body);
    const email = data.email;

    if (await UserModel.existsByEmail(email)) {
      throw new HttpError(409, 'Email is already registered');
    }

    const hash = await bcrypt.hash(data.password, 10);
    const user = await UserModel.create({
      email,
      passwordHash: hash,
      fullName: data.fullName,
      studentNo: data.studentNo ?? null,
      course: data.course ?? null,
    });

    res.status(201).json({ token: signToken(user), user: publicUser(user) });
  },

  login: async (req, res) => {
    const data = validate(loginSchema, req.body);
    const user = await UserModel.findByEmail(data.email);

    if (!user || !(await bcrypt.compare(data.password, user.password_hash))) {
      throw new HttpError(401, 'Invalid email or password');
    }

    res.json({ token: signToken(user), user: publicUser(user) });
  },

  me: async (req, res) => {
    const user = await UserModel.findById(req.userId);
    if (!user) throw new HttpError(404, 'User not found');
    res.json({ data: publicUser(user) });
  },
};

module.exports = AuthController;
