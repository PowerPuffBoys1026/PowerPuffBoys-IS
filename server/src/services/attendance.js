const db = require('../db');
const config = require('../config');

/**
 * Per-subject attendance figures for one user.
 *
 * The calculation lives in the PostgreSQL routine `get_attendance_summary`
 * (migration 005) so the API and any direct DB client share one source of
 * truth. Attendance rate counts present / (present + absent + late); cancelled
 * sessions are ignored. `warning` is true once the absence rate reaches the
 * configured threshold or the student has used the 28-session allowance.
 */
async function attendanceSummary(userId) {
  const result = await db.query('SELECT * FROM get_attendance_summary($1, $2)', [
    userId,
    config.attendanceThreshold,
  ]);

  return result.rows.map((row) => ({
    subjectId: row.subject_id,
    code: row.code,
    title: row.title,
    color: row.color,
    present: Number(row.present) || 0,
    absent: Number(row.absent) || 0,
    late: Number(row.late) || 0,
    cancelled: Number(row.cancelled) || 0,
    counted: Number(row.counted) || 0,
    attendanceRate: row.attendance_rate === null ? null : Number(row.attendance_rate),
    absenceRate: row.absence_rate === null ? null : Number(row.absence_rate),
    safeMissesLeft: Number(row.safe_misses_left) || 0,
    healthStatus: row.health_status,
    warning: Boolean(row.warning),
  }));
}

module.exports = { attendanceSummary };
