const express = require('express');
const { asyncHandler } = require('../utils/asyncHandler');
const ClientConfigController = require('../controllers/client-config.controller');

const router = express.Router();

// GET /api/client-config — public, contains no user data or secrets.
router.get('/', asyncHandler(ClientConfigController.get));

module.exports = router;
