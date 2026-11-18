const jwt = require('jsonwebtoken');
const config = require('../config');
const { HttpError } = require('../utils/errors');

/** Require a valid `Authorization: Bearer <jwt>` header; sets req.userId. */
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return next(new HttpError(401, 'Missing or malformed Authorization header'));
  }

  try {
    const payload = jwt.verify(token, config.jwtSecret);
    req.userId = Number(payload.sub);
    return next();
  } catch (error) {
    // Phones can distinguish an expired session (re-login) from a bad token.
    if (error instanceof jwt.TokenExpiredError) {
      const expired = new HttpError(401, 'Token expired');
      expired.errorCode = 'TOKEN_EXPIRED';
      return next(expired);
    }
    return next(new HttpError(401, 'Invalid token'));
  }
}

module.exports = { requireAuth };
