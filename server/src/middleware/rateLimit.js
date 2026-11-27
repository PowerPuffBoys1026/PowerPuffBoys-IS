const rateLimit = require('express-rate-limit');
const config = require('../config');

/**
 * Limits repeated credential attempts from the same IP. Successful requests
 * count too, which keeps the rule simple and predictable. Phones behind the
 * same NAT share an IP, so both the window and limit are configurable in .env.
 */
const authLimiter = rateLimit({
  windowMs: config.authRateLimitWindowMs,
  limit: config.authRateLimitMax,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { error: { message: 'Too many attempts. Please try again later.' } },
});

module.exports = { authLimiter };
