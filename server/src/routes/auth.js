const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { authLimiter } = require('../middleware/rateLimit');
const AuthController = require('../controllers/auth.controller');
const { asyncHandler } = require('../utils/asyncHandler');

const router = express.Router();

// POST /api/auth/register
router.post('/register', authLimiter, asyncHandler(AuthController.register));

// POST /api/auth/login
router.post('/login', authLimiter, asyncHandler(AuthController.login));

// GET /api/auth/me
router.get('/me', requireAuth, asyncHandler(AuthController.me));

// PUT /api/auth/me
router.put('/me', requireAuth, asyncHandler(AuthController.updateMe));

// PUT /api/auth/me/password
router.put('/me/password', requireAuth, asyncHandler(AuthController.updatePassword));

module.exports = router;
