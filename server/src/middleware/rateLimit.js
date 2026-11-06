const rateLimit = require('express-rate-limit');

/**
 * Limits repeated credential attempts from the same IP. Successful requests
 * count too, which keeps the rule simple and predictable.
 */
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { error: { message: 'Too many attempts. Please try again later.' } },
});

module.exports = { authLimiter };
