const { query } = require('../db');
const config = require('../config');

/**
 * Per-subject attendance figures for one user.
 * Attendance rate counts present / (present + absent + late); cancelled
 * sessions are ignored. `warning` is true once the absence rate reaches the
 * configured threshold.
 */
async function attendanceSummary(userId) {
  const { rows } = await query(
    `SELECT s.id,
            s.code,
            s.title,
            s.color,
            COUNT(a.id) FILTER (WHERE a.status = 'present')::int   AS present,
            COUNT(a.id) FILTER (WHERE a.status = 'absent')::int    AS absent,
            COUNT(a.id) FILTER (WHERE a.status = 'late')::int      AS late,
            COUNT(a.id) FILTER (WHERE a.status = 'cancelled')::int AS cancelled
       FROM subjects s
       LEFT JOIN attendance_records a ON a.subject_id = s.id
      WHERE s.user_id = $1
      GROUP BY s.id, s.code, s.title, s.color
      ORDER BY s.code`,
    [userId],
  );

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
