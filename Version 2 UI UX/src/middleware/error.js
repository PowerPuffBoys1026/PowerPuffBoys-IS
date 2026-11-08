const { HttpError } = require('../utils/errors');

/** Catch-all for unmatched routes. */
function notFound(req, res, next) {
  next(new HttpError(404, `Route not found: ${req.method} ${req.originalUrl}`));
}

/** Central error handler. Produces { error: { message, details? } }. */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const status = err.status || 500;
  const body = { error: { message: status === 500 ? 'Internal server error' : err.message } };

  if (err.details) body.error.details = err.details;
  if (status === 500) console.error(err);

  res.status(status).json(body);
}

module.exports = { notFound, errorHandler };
