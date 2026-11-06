const { HttpError } = require('../utils/errors');

/** Catch-all for unmatched routes. */
function notFound(req, res, next) {
  next(new HttpError(404, `Route not found: ${req.method} ${req.originalUrl}`));
}

/** PostgreSQL error codes we can translate into client errors. */
const PG_ERRORS = {
  '22P02': { status: 400, message: 'Invalid input format' },
  '22007': { status: 400, message: 'Invalid date or time value' },
  '22008': { status: 400, message: 'Date or time value out of range' },
  '23502': { status: 400, message: 'A required field is missing' },
  '23503': { status: 400, message: 'Related resource not found' },
  '23505': { status: 409, message: 'This record already exists' },
  '23514': { status: 400, message: 'Value violates a database constraint' },
};

/** Central error handler. Produces { error: { message, details? } }. */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  let status = err.status;
  let message = err.message;

  if (!status && err.type === 'entity.parse.failed') {
    status = 400;
    message = 'Invalid JSON body';
  } else if (!status && err.type === 'entity.too.large') {
    status = 413;
    message = 'Request body is too large';
  } else if (!status && err.code && PG_ERRORS[err.code]) {
    ({ status, message } = PG_ERRORS[err.code]);
  }

  if (!status) {
    status = 500;
    message = 'Internal server error';
  }

  const body = { error: { message } };
  if (err.details) body.error.details = err.details;
  if (status === 500) console.error(err);

  res.status(status).json(body);
}

module.exports = { notFound, errorHandler };
