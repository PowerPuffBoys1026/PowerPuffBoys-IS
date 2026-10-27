const db = require('../db');
const config = require('../config');

/**
 * Per-subject attendance figures for one user.
 * Attendance rate counts present / (present + absent + late); cancelled
 * sessions are ignored. `warning` is true once the absence rate reaches the
 * configured threshold.
 */
function attendanceSummary(userId) {
  const rows = db
    .prepare(
      `SELECT s.id,
              s.code,
              s.title,
              s.color,
              SUM(CASE WHEN a.status = 'present'   THEN 1 ELSE 0 END) AS present,
              SUM(CASE WHEN a.status = 'absent'    THEN 1 ELSE 0 END) AS absent,
              SUM(CASE WHEN a.status = 'late'      THEN 1 ELSE 0 END) AS late,
              SUM(CASE WHEN a.status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled
         FROM subjects s
         LEFT JOIN attendance_records a ON a.subject_id = s.id
        WHERE s.user_id = ?
        GROUP BY s.id
        ORDER BY s.code`,
    )
    .all(userId);

  return rows.map((row) => {
    const counted = row.present + row.absent + row.late;
    const attendanceRate = counted ? Math.round((row.present / counted) * 1000) / 10 : null;
    const absenceRate = counted ? Math.round((row.absent / counted) * 1000) / 10 : null;

    return {
      subjectId: row.id,
      code: row.code,
      title: row.title,
      color: row.color,
      present: row.present,
      absent: row.absent,
      late: row.late,
      cancelled: row.cancelled,
      counted,
      attendanceRate,
      absenceRate,
      warning: absenceRate !== null && absenceRate >= config.attendanceThreshold,
    };
  });
}

module.exports = { attendanceSummary };
