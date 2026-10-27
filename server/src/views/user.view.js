/**
 * View: shapes a user row into the public JSON payload.
 * Never exposes password_hash.
 */
function publicUser(row) {
  return {
    id: row.id,
    email: row.email,
    fullName: row.full_name,
    studentNo: row.student_no,
    course: row.course,
    createdAt: row.created_at,
  };
}

module.exports = { publicUser };
