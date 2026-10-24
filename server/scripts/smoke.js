/**
 * End-to-end smoke test. Uses an isolated port and a throwaway database so it
 * never touches real data.
 *   npm run smoke
 */
const path = require('node:path');
const fs = require('node:fs');

process.env.PORT = process.env.SMOKE_PORT || '3999';
process.env.DB_FILE = path.join(__dirname, '..', 'data', 'smoke.db');
process.env.JWT_SECRET = 'smoke-secret';
const uploadsDirectory = path.join(path.dirname(process.env.DB_FILE), 'smoke-uploads');
fs.rmSync(uploadsDirectory, { recursive: true, force: true });

// Start from a clean database.
for (const suffix of ['', '-wal', '-shm']) {
  const file = process.env.DB_FILE + suffix;
  if (fs.existsSync(file)) fs.unlinkSync(file);
}

const app = require('../src/app');

const BASE = `http://localhost:${process.env.PORT}/api`;
let passed = 0;

function check(name, condition) {
  if (!condition) throw new Error(`FAIL: ${name}`);
  passed += 1;
  console.log(`  ok  ${name}`);
}

async function req(method, url, { token, body } = {}) {
  const res = await fetch(BASE + url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, json: text ? JSON.parse(text) : null };
}

async function uploadFile(resourceType, resourceId, { token, name, type, content }) {
  const formData = new FormData();
  formData.append('file', new Blob([content], { type }), name);
  const res = await fetch(`${BASE}/attachments/${resourceType}/${resourceId}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: formData,
  });
  const text = await res.text();
  return { status: res.status, json: text ? JSON.parse(text) : null };
}

async function main() {
  const server = app.listen(process.env.PORT);
  await new Promise((resolve) => server.once('listening', resolve));
  console.log(`Smoke test against ${BASE}\n`);

  let r = await req('GET', '/health');
  check('health responds ok', r.status === 200 && r.json.status === 'ok');

  const email = `student+${Date.now()}@example.com`;
  r = await req('POST', '/auth/register', { body: { email, password: 'password123', fullName: 'Test Student', yearLevel: '1st Year' } });
  check('register returns 201 + token', r.status === 201 && !!r.json.token);
  check('registration saves year level', r.json.user.yearLevel === '1st Year');
  const token = r.json.token;

  r = await req('POST', '/auth/register', { body: { email, password: 'password123', fullName: 'Test Student' } });
  check('duplicate email -> 409', r.status === 409);

  r = await req('POST', '/auth/register', { body: { email: 'not-an-email', password: 'x' } });
  check('invalid register -> 400 with details', r.status === 400 && Array.isArray(r.json.error.details));

  r = await req('GET', '/subjects');
  check('protected route without token -> 401', r.status === 401);

  r = await req('POST', '/auth/login', { body: { email, password: 'password123' } });
  check('login returns token', r.status === 200 && !!r.json.token);

  r = await req('POST', '/auth/login', { body: { email, password: 'wrong-password' } });
  check('wrong password -> 401', r.status === 401);

  r = await req('PUT', '/auth/me', { token, body: { fullName: 'Updated Student', studentNo: 'S-100', course: 'Computer Science', yearLevel: '3rd Year' } });
  check('update profile persists student details', r.status === 200 && r.json.data.fullName === 'Updated Student' && r.json.data.studentNo === 'S-100' && r.json.data.yearLevel === '3rd Year');

  r = await req('PUT', '/auth/me/password', { token, body: { currentPassword: 'wrong-password', newPassword: 'new-password-456' } });
  check('password update rejects incorrect current password', r.status === 400);
  r = await req('PUT', '/auth/me/password', { token, body: { currentPassword: 'password123', newPassword: 'new-password-456' } });
  check('password update requires current password and succeeds', r.status === 200 && r.json.data.success);
  r = await req('POST', '/auth/login', { body: { email, password: 'new-password-456' } });
  check('updated password can sign in', r.status === 200 && !!r.json.token);

  r = await req('POST', '/subjects', {
    token,
    body: {
      code: 'CS101',
      title: 'Intro to Computing',
      units: 3,
      instructorEmail: 'instructor@example.edu',
      officeHours: 'Tue 1:00–3:00 PM',
    },
  });
  check('create subject -> 201', r.status === 201 && r.json.data.code === 'CS101');
  check('subject returns instructor contact details', r.json.data.instructorEmail === 'instructor@example.edu' && r.json.data.officeHours === 'Tue 1:00–3:00 PM');
  const subjectId = r.json.data.id;

  r = await req('GET', '/subjects', { token });
  check('list subjects', r.status === 200 && r.json.data.length === 1);

  r = await req('POST', '/schedule', {
    token,
    body: {
      subjectId,
      dayOfWeek: 1,
      startTime: '08:00',
      endTime: '09:30',
      room: 'Lab 2',
      building: 'Science Hall',
      weekPattern: 'a',
    },
  });
  check('create schedule slot -> 201', r.status === 201 && r.json.data.weekPattern === 'a' && r.json.data.building === 'Science Hall');
  const slotId = r.json.data.id;

  r = await req('PUT', `/schedule/${slotId}`, { token, body: { startTime: '08:30', endTime: '10:00' } });
  check('update schedule slot', r.status === 200 && r.json.data.startTime === '08:30');

  r = await req('POST', '/schedule', { token, body: { subjectId, dayOfWeek: 1, startTime: '25:00', endTime: '09:30' } });
  check('invalid time -> 400', r.status === 400);

  r = await req('GET', '/schedule?day=1', { token });
  check('schedule filter matches day', r.status === 200 && r.json.data.length === 1);
  r = await req('GET', '/schedule?day=3', { token });
  check('schedule filter empty day', r.status === 200 && r.json.data.length === 0);

  r = await req('DELETE', `/schedule/${slotId}`, { token });
  const slotBinId = r.json.data.recycleBinId;
  check('delete schedule slot moves it to recycle bin', r.status === 200 && !!slotBinId);
  r = await req('POST', `/recycle-bin/${slotBinId}/restore`, { token });
  check('restore schedule slot succeeds', r.status === 200 && r.json.data.type === 'schedule');
  r = await req('GET', '/schedule', { token });
  check('restored schedule slot is listed', r.status === 200 && r.json.data.some((slot) => slot.id === slotId));

  const today = new Date().toISOString().slice(0, 10);
  r = await req('POST', '/attendance', { token, body: { subjectId, slotId, date: today, status: 'present' } });
  check('mark attendance -> 201', r.status === 201);
  const attendanceId = r.json.data.id;

  r = await req('POST', '/attendance', { token, body: { subjectId, slotId, date: today, status: 'absent' } });
  check('duplicate attendance -> 409', r.status === 409);

  await req('POST', '/attendance', { token, body: { subjectId, date: today, status: 'absent' } });

  r = await req('GET', '/attendance/summary', { token });
  const summary = r.json.data[0];
  check('summary counts present + absent', r.status === 200 && summary.present === 1 && summary.absent === 1);
  check('attendance rate is 50%', summary.attendanceRate === 50);
  check('absence warning flagged', summary.warning === true);

  r = await req('DELETE', `/attendance/${attendanceId}`, { token });
  const attendanceBinId = r.json.data.recycleBinId;
  check('delete attendance record moves it to recycle bin', r.status === 200 && !!attendanceBinId);
  r = await req('POST', `/recycle-bin/${attendanceBinId}/restore`, { token });
  check('restore attendance record succeeds', r.status === 200 && r.json.data.type === 'attendance');
  r = await req('GET', '/attendance', { token });
  check('restored attendance record is listed', r.status === 200 && r.json.data.some((record) => record.id === attendanceId));

  const dueAt = new Date(Date.now() + 3 * 86400000).toISOString();
  r = await req('POST', '/works', { token, body: { title: 'Lab 1', subjectId, dueAt, priority: 'high' } });
  check('create school work -> 201', r.status === 201);
  const workId = r.json.data.id;

  r = await uploadFile('works', workId, { token, name: 'lab-notes.pdf', type: 'application/pdf', content: '%PDF smoke attachment' });
  check('upload PDF to school work -> 201', r.status === 201 && r.json.data.resourceId === workId && r.json.data.mimeType === 'application/pdf');
  const workAttachmentId = r.json.data.id;
  const workAttachmentPath = path.join(uploadsDirectory, require('../src/db').prepare('SELECT stored_name FROM attachments WHERE id = ?').get(workAttachmentId).stored_name);
  check('uploaded work file is stored outside public', fs.existsSync(workAttachmentPath));
  r = await req('GET', '/attachments/works', { token });
  check('list school-work attachments', r.status === 200 && r.json.data.some((file) => file.id === workAttachmentId));
  let download = await fetch(`${BASE}/attachments/${workAttachmentId}/download`, { headers: { Authorization: `Bearer ${token}` } });
  check('download school-work attachment', download.status === 200 && (await download.text()) === '%PDF smoke attachment' && download.headers.get('content-disposition').includes('attachment'));
  r = await uploadFile('works', workId, { token, name: 'run-me.exe', type: 'application/octet-stream', content: 'not allowed' });
  check('reject unsupported attachment types', r.status === 415);

  r = await req('PUT', `/works/${workId}`, { token, body: { title: 'Updated Lab 1', priority: 'low' } });
  check('update school work', r.status === 200 && r.json.data.title === 'Updated Lab 1' && r.json.data.priority === 'low');

  r = await req('PATCH', `/works/${workId}/status`, { token, body: { status: 'done' } });
  check('patch work status', r.status === 200 && r.json.data.status === 'done');

  r = await req('GET', '/dashboard/today', { token });
  check('dashboard returns classes + dueSoon', r.status === 200 && Array.isArray(r.json.data.classes) && Array.isArray(r.json.data.dueSoon));
  check('dashboard surfaces attendance warning', r.json.data.attendanceWarnings.length === 1);

  const email2 = `other+${Date.now()}@example.com`;
  r = await req('POST', '/auth/register', { body: { email: email2, password: 'password123', fullName: 'Other Student' } });
  const token2 = r.json.token;
  r = await req('GET', `/subjects/${subjectId}`, { token: token2 });
  check('another user cannot read the subject -> 404', r.status === 404);
  download = await fetch(`${BASE}/attachments/${workAttachmentId}/download`, { headers: { Authorization: `Bearer ${token2}` } });
  check('another user cannot download an attachment -> 404', download.status === 404);

  r = await req('DELETE', `/works/${workId}`, { token });
  check('delete work moves it to recycle bin', r.status === 200 && !!r.json.data.recycleBinId);
  const workBinId = r.json.data.recycleBinId;
  r = await req('GET', '/recycle-bin', { token });
  const trashedWork = r.json.data.find((item) => item.id === workBinId);
  check('recycle bin lists deleted work', r.status === 200 && trashedWork?.type === 'task' && trashedWork.label === 'Updated Lab 1');
  const retentionMs = Date.parse(`${trashedWork.expiresAt.replace(' ', 'T')}Z`) - Date.parse(`${trashedWork.deletedAt.replace(' ', 'T')}Z`);
  check('recycle retention is exactly 30 days', retentionMs === 30 * 24 * 60 * 60 * 1000);
  r = await req('POST', `/recycle-bin/${workBinId}/restore`, { token: token2 });
  check('another user cannot restore deleted work', r.status === 404);
  r = await req('GET', '/attachments/works', { token });
  check('trashed work attachments are not exposed', r.status === 200 && !r.json.data.some((file) => file.id === workAttachmentId));
  r = await req('POST', `/recycle-bin/${workBinId}/restore`, { token });
  check('restore work succeeds', r.status === 200 && r.json.data.type === 'task');
  r = await req('GET', '/works', { token });
  check('restored work returns to task list', r.json.data.some((item) => item.id === workId));
  r = await req('GET', '/attachments/works', { token });
  check('restored work attachments are available again', r.status === 200 && r.json.data.some((file) => file.id === workAttachmentId));

  r = await req('DELETE', `/works/${workId}`, { token });
  const expiringBinId = r.json.data.recycleBinId;
  require('../src/db').prepare("UPDATE recycle_bin SET expires_at = datetime('now', '-1 second') WHERE id = ?").run(expiringBinId);
  r = await req('GET', '/recycle-bin', { token });
  check('expired content is purged and no longer recoverable', r.status === 200 && !r.json.data.some((item) => item.id === expiringBinId));
  check('expired work attachment file is removed', !fs.existsSync(workAttachmentPath));

  // New features smoke checks
  r = await req('POST', '/study/sessions', {
    token,
    body: { subjectId, durationMinutes: 25, mode: 'focus', notes: 'Smoke study' },
  });
  check('create study session -> 201', r.status === 201 && r.json.data.durationMinutes === 25);
  const sessionId = r.json.data.id;

  r = await req('GET', '/study/stats', { token });
  check('get study stats returns streak and minutes', r.status === 200 && r.json.data.streakDays >= 1);

  r = await req('DELETE', `/study/sessions/${sessionId}`, { token });
  const sessionBinId = r.json.data.recycleBinId;
  check('delete study session moves it to recycle bin', r.status === 200 && !!sessionBinId);
  r = await req('POST', `/recycle-bin/${sessionBinId}/restore`, { token });
  check('restore study session succeeds', r.status === 200 && r.json.data.type === 'session');
  r = await req('GET', '/study/sessions', { token });
  check('restored study session is listed', r.status === 200 && r.json.data.some((session) => session.id === sessionId));

  r = await req('POST', '/notes', {
    token,
    body: { subjectId, title: 'Exam Formula Sheet', content: 'Derivative rules and proofs', isPinned: true },
  });
  check('create flashnote -> 201', r.status === 201 && r.json.data.title === 'Exam Formula Sheet');

  r = await req('GET', '/notes', { token });
  check('get notes returns list with pinned item', r.status === 200 && r.json.data.length >= 1);
  const noteId = r.json.data[0].id;
  r = await uploadFile('notes', noteId, { token, name: 'formula-sheet.png', type: 'image/png', content: 'smoke image attachment' });
  check('upload image to flashnote -> 201', r.status === 201 && r.json.data.resourceType === 'note');
  const noteAttachmentId = r.json.data.id;
  r = await req('PUT', `/notes/${noteId}`, { token, body: { isPinned: false } });
  check('unpin note persists', r.status === 200 && r.json.data.isPinned === false);
  r = await req('DELETE', `/notes/${noteId}`, { token });
  const noteBinId = r.json.data.recycleBinId;
  r = await req('POST', `/recycle-bin/${noteBinId}/restore`, { token });
  check('restore note succeeds', r.status === 200 && r.json.data.type === 'note');
  r = await req('GET', '/notes', { token });
  check('restored note retains pin state', r.status === 200 && r.json.data.find((item) => item.id === noteId)?.isPinned === false);
  r = await req('GET', `/attachments/notes/${noteId}`, { token });
  check('restored flashnote keeps its image attachment', r.status === 200 && r.json.data.some((file) => file.id === noteAttachmentId));

  r = await req('POST', '/grades', {
    token,
    body: { subjectId, componentName: 'Midterm', weightPct: 40, scorePct: 90, targetPct: 88 },
  });
  check('create grade component -> 201', r.status === 201 && r.json.data.scorePct === 90);

  r = await req('GET', '/grades/summary', { token });
  check('get grades summary returns cumulative GPA', r.status === 200 && r.json.data.subjects.length >= 1);
  r = await req('GET', '/grades', { token });
  const gradeId = r.json.data[0].id;
  r = await req('DELETE', `/grades/${gradeId}`, { token });
  const gradeBinId = r.json.data.recycleBinId;
  check('delete grade component moves it to recycle bin', r.status === 200 && !!gradeBinId);
  r = await req('POST', `/recycle-bin/${gradeBinId}/restore`, { token });
  check('restore grade component succeeds', r.status === 200 && r.json.data.type === 'grade');
  r = await req('GET', '/grades', { token });
  check('restored grade component is listed', r.status === 200 && r.json.data.some((grade) => grade.id === gradeId));

  r = await req('DELETE', `/study/sessions/${sessionId}`, { token });
  const permanentBinId = r.json.data.recycleBinId;
  r = await req('DELETE', `/recycle-bin/${permanentBinId}`, { token });
  check('permanently delete recycle-bin item succeeds', r.status === 204);

  r = await req('DELETE', `/subjects/${subjectId}`, { token });
  const subjectBinId = r.json.data.recycleBinId;
  check('delete course moves course and related records to recycle bin', r.status === 200 && !!subjectBinId);
  r = await req('GET', '/schedule', { token });
  check('deleted course hides its schedule', r.status === 200 && r.json.data.length === 0);
  r = await req('POST', `/recycle-bin/${subjectBinId}/restore`, { token });
  check('restore course and related records succeeds', r.status === 200 && r.json.data.type === 'subject');
  r = await req('GET', '/schedule', { token });
  check('restored course restores its schedule', r.status === 200 && r.json.data.length === 1);
  r = await req('GET', '/notes', { token });
  check('restored course keeps its notes', r.status === 200 && r.json.data.some((note) => note.id === noteId));
  r = await req('GET', `/attachments/notes/${noteId}`, { token });
  check('course restore keeps note attachments', r.status === 200 && r.json.data.some((file) => file.id === noteAttachmentId));

  const cleanupWork = await req('POST', '/works', { token, body: { title: 'Attachment cleanup check', subjectId } });
  const cleanupWorkId = cleanupWork.json.data.id;
  const cleanupUpload = await uploadFile('works', cleanupWorkId, { token, name: 'cleanup.txt', type: 'text/plain', content: 'cleanup' });
  const cleanupAttachmentId = cleanupUpload.json.data.id;
  const cleanupAttachmentPath = path.join(uploadsDirectory, require('../src/db').prepare('SELECT stored_name FROM attachments WHERE id = ?').get(cleanupAttachmentId).stored_name);
  const cleanupBin = await req('DELETE', `/works/${cleanupWorkId}`, { token });
  r = await req('DELETE', `/recycle-bin/${cleanupBin.json.data.recycleBinId}`, { token });
  check('permanent work deletion clears attachment metadata and file', r.status === 204
    && !require('../src/db').prepare('SELECT id FROM attachments WHERE id = ?').get(cleanupAttachmentId)
    && !fs.existsSync(cleanupAttachmentPath));

  // Close the server and the SQLite handle before deleting the throwaway DB.
  await new Promise((resolve) => server.close(resolve));
  require('../src/db').close();
  for (const suffix of ['', '-wal', '-shm']) {
    const file = process.env.DB_FILE + suffix;
    if (fs.existsSync(file)) fs.unlinkSync(file);
  }
  fs.rmSync(uploadsDirectory, { recursive: true, force: true });

  console.log(`\nAll ${passed} checks passed.`);
}

main().catch((err) => {
  console.error('\nSMOKE TEST FAILED');
  console.error(err);
  process.exit(1);
});
