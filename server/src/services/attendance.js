const db = require('../db');
const config = require('../config');

/**
 * Per-subject attendance figures for one user.
 * Attendance rate counts present / (present + absent + late); cancelled
 * sessions are ignored. `warning` is true once the absence rate reaches the
 * configured threshold.
 */
async function attendanceSummary(userId) {
  const result = await db.query(
    `SELECT s.id,
            s.code,
            s.title,
            s.color,
            SUM(CASE WHEN a.status = 'present'   THEN 1 ELSE 0 END)::int AS present,
            SUM(CASE WHEN a.status = 'absent'    THEN 1 ELSE 0 END)::int AS absent,
            SUM(CASE WHEN a.status = 'late'      THEN 1 ELSE 0 END)::int AS late,
            SUM(CASE WHEN a.status = 'cancelled' THEN 1 ELSE 0 END)::int AS cancelled
       FROM subjects s
       LEFT JOIN attendance_records a ON a.subject_id = s.id
      WHERE s.user_id = $1
      GROUP BY s.id, s.code, s.title, s.color
      ORDER BY s.code`,
    [userId],
  );

  const rows = result.rows;

  return rows.map((row) => {
    const present = Number(row.present) || 0;
    const absent = Number(row.absent) || 0;
    const late = Number(row.late) || 0;
    const cancelled = Number(row.cancelled) || 0;
    const counted = present + absent + late;
    const attendanceRate = counted ? Math.round((present / counted) * 1000) / 10 : null;
    const absenceRate = counted ? Math.round((absent / counted) * 1000) / 10 : null;

    return {
      subjectId: row.id,
      code: row.code,
      title: row.title,
      color: row.color,
      present,
      absent,
      late,
      cancelled,
      counted,
      attendanceRate,
      absenceRate,
      warning: absenceRate !== null && absenceRate >= config.attendanceThreshold,
    };
  });
}

module.exports = { attendanceSummary };
