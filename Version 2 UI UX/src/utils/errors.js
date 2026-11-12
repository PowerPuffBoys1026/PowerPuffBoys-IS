/**
 * Small typed HTTP error used across the API.
 * Anything thrown inside a synchronous Express handler is forwarded to the
 * central error middleware, which turns it into the standard JSON error shape.
 */
class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

module.exports = { HttpError };
