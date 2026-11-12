const db = require('../db');
const config = require('../config');

/**
 * Per-subject attendance figures for one user.
 * Attendance rate counts present / (present + absent + late); cancelled
 * sessions are ignored. `warning` is true once the absence rate reaches the
 * configured threshold.
 */
async function attendanceSummary(userId) {
  const result = await db.query('SELECT * FROM fn_attendance_summary($1)', [userId]);
  const rows = result.rows;

  return rows.map((row) => {
    const present = Number(row.present) || 0;
    const absent = Number(row.absent) || 0;
    const late = Number(row.late) || 0;
    const cancelled = Number(row.cancelled) || 0;
    const counted = present + absent + late;
    const attendanceRate = counted ? Math.round((present / counted) * 1000) / 10 : null;
    const absenceRate = counted ? Math.round((absent / counted) * 1000) / 10 : null;
    const maxAllowedAbsences = Math.max(3, Math.floor((config.attendanceThreshold / 100) * 28));
    const safeMissesLeft = Math.max(0, maxAllowedAbsences - absent);
    let healthStatus = 'safe';
    if (absenceRate !== null && (absenceRate >= config.attendanceThreshold || absent >= maxAllowedAbsences)) {
      healthStatus = absent > maxAllowedAbsences ? 'critical' : 'warning';
    }

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
      safeMissesLeft,
      healthStatus,
      warning: absenceRate !== null && (absenceRate >= config.attendanceThreshold || absent >= maxAllowedAbsences),
    };
  });
}

module.exports = { attendanceSummary };
