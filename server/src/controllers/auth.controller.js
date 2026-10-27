const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { z } = require('zod');

const config = require('../config');
const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const UserModel = require('../models/user.model');
const { publicUser } = require('../views/user.view');

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  fullName: z.string().min(1, 'Full name is required'),
  studentNo: z.string().optional(),
  course: z.string().optional(),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1, 'Password is required'),
});

function signToken(user) {
  return jwt.sign({ sub: String(user.id) }, config.jwtSecret, { expiresIn: config.jwtExpiresIn });
}

const AuthController = {
  register: (req, res) => {
    const data = validate(registerSchema, req.body);
    const email = data.email.toLowerCase();

    if (UserModel.existsByEmail(email)) {
      throw new HttpError(409, 'Email is already registered');
    }

    const hash = bcrypt.hashSync(data.password, 10);
    const user = UserModel.create({
      email,
      passwordHash: hash,
      fullName: data.fullName,
      studentNo: data.studentNo ?? null,
      course: data.course ?? null,
    });

    res.status(201).json({ token: signToken(user), user: publicUser(user) });
  },

  login: (req, res) => {
    const data = validate(loginSchema, req.body);
    const user = UserModel.findByEmail(data.email.toLowerCase());

    if (!user || !bcrypt.compareSync(data.password, user.password_hash)) {
      throw new HttpError(401, 'Invalid email or password');
    }

    res.json({ token: signToken(user), user: publicUser(user) });
  },

  me: (req, res) => {
    const user = UserModel.findById(req.userId);
    if (!user) throw new HttpError(404, 'User not found');
    res.json({ data: publicUser(user) });
  },
};

module.exports = AuthController;
