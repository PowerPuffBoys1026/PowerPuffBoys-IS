const { HttpError } = require('./errors');

/**
 * Parse `data` against a zod schema. On failure throws a 400 HttpError whose
 * `details` describe each invalid field.
 */
function validate(schema, data) {
  const result = schema.safeParse(data);
  if (!result.success) {
    const details = result.error.issues.map((issue) => ({
      path: issue.path.join('.') || '(root)',
      message: issue.message,
    }));
    throw new HttpError(400, 'Validation failed', details);
  }
  return result.data;
}

module.exports = { validate };
