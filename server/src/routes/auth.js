const express = require('express');
const { requireAuth } = require('../middleware/auth');
const AuthController = require('../controllers/auth.controller');

const router = express.Router();

// POST /api/auth/register
router.post('/register', AuthController.register);

// POST /api/auth/login
router.post('/login', AuthController.login);

// GET /api/auth/me
router.get('/me', requireAuth, AuthController.me);

module.exports = router;
