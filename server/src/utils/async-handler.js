/**
 * Express 4 does not forward rejected promises to the error middleware.
 * Wrap async controllers so thrown errors reach the central handler.
 */
function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

module.exports = { asyncHandler };
