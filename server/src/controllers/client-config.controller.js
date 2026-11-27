const config = require('../config');

// Keep these lists in sync with the zod schemas in the feature controllers.
const ENUMS = {
  attendanceStatus: ['present', 'absent', 'late', 'cancelled'],
  workType: ['assignment', 'quiz', 'exam', 'project'],
  workStatus: ['todo', 'doing', 'done'],
  priority: ['low', 'medium', 'high'],
};

/**
 * Non-secret configuration a mobile client can fetch once at startup instead
 * of hard-coding thresholds, enums or payload limits in the app.
 */
const ClientConfigController = {
  get: async (req, res) => {
    res.json({
      service: 'classmate-api',
      version: 2,
      appTimezone: config.appTimezone,
      attendanceThreshold: config.attendanceThreshold,
      jwtExpiresIn: config.jwtExpiresIn,
      limits: {
        jsonBodyBytes: config.jsonBodyLimitBytes,
        attachmentBytes: config.attachmentMaxBytes,
        maxPageSize: config.maxPageSize,
      },
      enums: ENUMS,
    });
  },
};

module.exports = ClientConfigController;
