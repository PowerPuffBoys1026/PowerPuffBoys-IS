/**
 * ClassMate 2.0 — Modern Student Academic & Focus Suite Client
 * Connects directly to localhost:3000/api
 */

const API_BASE = '/api';
let authToken = localStorage.getItem('classmate_token') || '';
let currentUser = null;

// App Data
let subjects = [];
let scheduleSlots = [];
let attendanceSummary = [];
let schoolWorks = [];
let dashboardData = null;
let studyStats = null;
let studySessions = [];
let notesList = [];
let workAttachments = [];
let noteAttachments = [];
let activeAttachmentPreviewUrl = null;
let recycleBinItems = [];
let gradesSummary = null;
let activeNoteId = null;
let editingNoteId = null;
let activeReviewMode = false;
let reviewAnswerVisible = false;
let reviewQueue = [];
let serviceWorkerRegistration = null;

// Timer State
let timerMode = 'focus'; // 'focus', 'short', 'long'
let timerTotalSeconds = 25 * 60;
let timerRemainingSeconds = 25 * 60;
let timerInterval = null;
let isTimerRunning = false;
let timerEndsAt = null;

// Audio Synthesizer State (Web Audio API)
let audioCtx = null;
let ambientGain = null;
let ambientNoiseNode = null;
let isAmbientActive = false;
let currentSoundscape = 'rain';

// ============================================================================
// API Helper
// ============================================================================
async function api(path, method = 'GET', body = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (authToken) headers['Authorization'] = `Bearer ${authToken}`;

  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    if (res.status === 401) {
      logout();
    }
    throw new Error(data.error?.message || 'Request failed');
  }
  return data;
}

// ============================================================================
// Initialization & Auth
// ============================================================================
async function init() {
  initTheme();
  initVisualizer();
  registerServiceWorker();

  if (authToken) {
    try {
      const meRes = await api('/auth/me');
      currentUser = meRes.data;
      updateUserUI();
      await refreshAllData();
      enterApplication();
    } catch (e) {
      showAuthModal();
    }
  } else {
    showAuthModal();
  }
}

function showAuthModal() {
  document.body.classList.add('auth-screen');
  document.getElementById('app').setAttribute('aria-hidden', 'true');
  document.getElementById('app').inert = true;
  document.querySelectorAll('.modal-overlay.open:not(#auth-modal)').forEach((modal) => modal.classList.remove('open'));
  const authModal = document.getElementById('auth-modal');
  authModal.inert = false;
  authModal.removeAttribute('aria-hidden');
  authModal.classList.add('open');
  document.getElementById('login-password').value = '';
  showLoginForm();
}

function enterApplication() {
  document.body.classList.remove('auth-screen');
  const app = document.getElementById('app');
  app.inert = false;
  app.removeAttribute('aria-hidden');
  const authModal = document.getElementById('auth-modal');
  authModal.inert = true;
  authModal.setAttribute('aria-hidden', 'true');
  authModal.classList.remove('open');
}

function showSignupForm() {
  document.getElementById('login-form').hidden = true;
  document.getElementById('signup-form').hidden = false;
  document.getElementById('auth-title').textContent = 'Create your account';
  document.getElementById('auth-description').textContent = 'Set up your student profile to get started.';
  document.getElementById('signup-email').value = document.getElementById('login-email').value;
  document.getElementById('signup-error').textContent = '';
  document.getElementById('signup-error').style.display = 'none';
}

function showLoginForm() {
  document.getElementById('signup-form').hidden = true;
  document.getElementById('login-form').hidden = false;
  document.getElementById('auth-title').textContent = 'Welcome back.';
  document.getElementById('auth-description').textContent = 'Pick up where your semester is taking you.';
  const signupEmail = document.getElementById('signup-email')?.value;
  if (signupEmail) document.getElementById('login-email').value = signupEmail;
  const loginError = document.getElementById('login-error');
  loginError.textContent = '';
  loginError.style.display = 'none';
}

async function handleRegister(e) {
  e.preventDefault();
  const errorBox = document.getElementById('signup-error');
  const payload = {
    fullName: document.getElementById('signup-full-name').value.trim(),
    email: document.getElementById('signup-email').value.trim(),
    password: document.getElementById('signup-password').value,
    studentNo: document.getElementById('signup-student-no').value.trim() || undefined,
    yearLevel: document.getElementById('signup-year-level').value.trim() || undefined,
    course: document.getElementById('signup-course').value.trim() || undefined,
  };

  try {
    const response = await fetch(`${API_BASE}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error?.message || 'Could not create account');

    authToken = data.token;
    localStorage.setItem('classmate_token', authToken);
    currentUser = data.user;
    updateUserUI();
    enterApplication();
    await refreshAllData();
    switchView('dashboard');
  } catch (error) {
    errorBox.textContent = error.message;
    errorBox.style.display = 'block';
  }
}

async function handleLogin(e) {
  e.preventDefault();
  const email = document.getElementById('login-email').value.trim();
  const password = document.getElementById('login-password').value;
  const errBox = document.getElementById('login-error');

  try {
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error?.message || 'Login failed');

    authToken = data.token;
    localStorage.setItem('classmate_token', authToken);
    currentUser = data.user;
    updateUserUI();
    enterApplication();
    await refreshAllData();
  } catch (err) {
    errBox.textContent = err.message;
    errBox.style.display = 'block';
  }
}

function logout() {
  authToken = '';
  currentUser = null;
  localStorage.removeItem('classmate_token');
  showAuthModal();
}

function updateUserUI() {
  if (!currentUser) return;
  document.getElementById('sidebar-user-name').textContent = currentUser.fullName;
  document.getElementById('sidebar-user-course').textContent = [currentUser.yearLevel, currentUser.course].filter(Boolean).join(' · ') || 'Student';
  const avatar = (currentUser.fullName[0] || 'S').toUpperCase();
  document.getElementById('sidebar-user-avatar').textContent = avatar;
  document.getElementById('mobile-user-avatar').textContent = avatar;
  document.getElementById('mobile-menu-avatar').textContent = avatar;
  document.getElementById('mobile-menu-user-name').textContent = currentUser.fullName;
  document.getElementById('dash-greeting').textContent = `Good ${getTimeGreeting()}, ${currentUser.fullName.split(' ')[0]}! 🚀`;
}

function openProfileModal() {
  if (!currentUser) return;
  document.getElementById('profile-email').value = currentUser.email || '';
  document.getElementById('profile-full-name').value = currentUser.fullName || '';
  document.getElementById('profile-student-no').value = currentUser.studentNo || '';
  document.getElementById('profile-year-level').value = currentUser.yearLevel || '';
  document.getElementById('profile-course').value = currentUser.course || '';
  document.getElementById('profile-password-form').reset();
  document.getElementById('profile-modal').classList.add('open');
}

async function handleProfileSave(e) {
  e.preventDefault();
  try {
    const result = await api('/auth/me', 'PUT', {
      fullName: document.getElementById('profile-full-name').value.trim(),
      studentNo: document.getElementById('profile-student-no').value.trim() || null,
      yearLevel: document.getElementById('profile-year-level').value.trim() || null,
      course: document.getElementById('profile-course').value.trim() || null,
    });
    currentUser = result.data;
    updateUserUI();
    closeModal('profile-modal');
    showToast('Student details updated.');
  } catch (error) {
    showToast(error.message, true);
  }
}

async function handlePasswordChange(e) {
  e.preventDefault();
  const currentPassword = document.getElementById('profile-current-password').value;
  const newPassword = document.getElementById('profile-new-password').value;
  const confirmPassword = document.getElementById('profile-confirm-password').value;
  if (newPassword !== confirmPassword) {
    showToast('New passwords do not match.', true);
    return;
  }

  try {
    await api('/auth/me/password', 'PUT', { currentPassword, newPassword });
    document.getElementById('profile-password-form').reset();
    showToast('Password changed successfully.');
  } catch (error) {
    showToast(error.message, true);
  }
}

function getTimeGreeting() {
  const h = new Date().getHours();
  return h < 12 ? 'Morning' : (h < 17 ? 'Afternoon' : 'Evening');
}

// ============================================================================
// Data Refresh & Views
// ============================================================================
async function refreshAllData() {
  try {
    const [subRes, slotRes, attRes, workRes, dashRes, statsRes, sessRes, notesRes, gradesRes, recycleRes, workAttachmentsRes, noteAttachmentsRes] = await Promise.all([
      api('/subjects'),
      api('/schedule'),
      api('/attendance/summary'),
      api('/works'),
      api('/dashboard/today'),
      api('/study/stats').catch(() => ({ data: null })),
      api('/study/sessions').catch(() => ({ data: [] })),
      api('/notes').catch(() => ({ data: [] })),
      api('/grades/summary').catch(() => ({ data: null })),
      api('/recycle-bin'),
      api('/attachments/works').catch(() => ({ data: [] })),
      api('/attachments/notes').catch(() => ({ data: [] })),
    ]);

    subjects = subRes.data || [];
    scheduleSlots = slotRes.data || [];
    attendanceSummary = attRes.data || [];
    schoolWorks = workRes.data || [];
    dashboardData = dashRes.data || null;
    studyStats = statsRes.data;
    studySessions = sessRes.data || [];
    notesList = notesRes.data || [];
    workAttachments = workAttachmentsRes.data || [];
    noteAttachments = noteAttachmentsRes.data || [];
    gradesSummary = gradesRes.data;
    recycleBinItems = recycleRes.data || [];

    renderDashboard();
    renderSchedule();
    renderAttendance();
    renderTasks();
    renderFocus();
    renderGrades();
    renderNotes();
    renderRecycleBin();
    populateSelects();
    renderWeeklyPlan();
    updateReminderButton();
    checkDeadlineReminders();
  } catch (e) {
    console.error('Data refresh error:', e);
  }
}

// ============================================================================
// 1. Dashboard Render
// ============================================================================
function renderDashboard() {
  if (!dashboardData) return;

  document.getElementById('dash-date-tag').textContent = `${dashboardData.dayName.toUpperCase()} · ${dashboardData.date}`;

  // Streak badge
  const streak = studyStats?.streakDays || 0;
  document.getElementById('dash-streak-badge').textContent = `🔥 ${streak}-Day Focus Streak`;

  // Next Class Hero Card
  const now = new Date();
  const nowTime = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
  const sortedClasses = [...(dashboardData.classes || [])].sort((a, b) => a.startTime.localeCompare(b.startTime));
  const nextClass = sortedClasses.find(c => c.startTime >= nowTime) || sortedClasses[0];

  const nextCard = document.getElementById('next-class-card');
  if (nextClass) {
    nextCard.innerHTML = `
      <div style="display: flex; align-items: center; justify-content: space-between; gap: 16px; flex-wrap: wrap;">
        <button type="button" class="dashboard-class-open next-class-open" onclick="openClassDetails(${nextClass.slotId})" aria-label="Open ${nextClass.code} class details">
          <span style="width: 52px; height: 52px; flex: 0 0 52px; border-radius: 14px; background: var(--primary-medium); color: var(--primary); display: flex; align-items: center; justify-content: center; font-size: 24px;">
            🎓
          </span>
          <div>
            <div style="display: flex; align-items: center; gap: 8px;">
              <span class="hero-tag" style="background: var(--primary); color: #fff; margin-bottom: 0;">UPCOMING CLASS</span>
              <span style="font-size: 13px; font-weight: 800; color: var(--primary);">${nextClass.code}</span>
            </div>
            <h3 style="font-size: 19px; font-weight: 800; margin-top: 4px;">${nextClass.title}</h3>
            <p style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">
              ${formatClock(nextClass.startTime)} – ${formatClock(nextClass.endTime)} · ${nextClass.room || nextClass.modality || 'Campus'}
            </p>
          </div>
        </button>
        <div style="display: flex; gap: 10px;">
          <button class="btn-primary" style="padding: 10px 18px; font-size: 13px;" onclick="quickMarkAttendance(${nextClass.subjectId}, ${nextClass.slotId}, 'present')">
            ✓ Mark Present
          </button>
        </div>
      </div>
    `;
  } else {
    nextCard.innerHTML = `
      <div style="display: flex; align-items: center; gap: 12px;">
        <div style="font-size: 24px;">✨</div>
        <div>
          <h3 style="font-size: 15px; font-weight: 800;">All Clear for Today!</h3>
          <p style="font-size: 12px; color: var(--text-muted);">No more classes scheduled today. Time to relax or jump into the Focus Zone.</p>
        </div>
      </div>
    `;
  }

  // Safe Skips Attendance Radar
  const radarStrip = document.getElementById('dash-radar-strip');
  radarStrip.innerHTML = attendanceSummary.map(s => `
    <button type="button" class="radar-chip radar-chip-button ${s.warning ? 'warning' : 'safe'}" onclick="openAttendanceSubject(${s.subjectId})" aria-label="Open attendance for ${s.code}">
      <div style="width: 8px; height: 8px; border-radius: 50%; background: ${s.color};"></div>
      <span style="font-size: 12.5px; font-weight: 800;">${s.code}</span>
      <span style="font-size: 11px; font-weight: 700; color: ${s.warning ? 'var(--rose)' : 'var(--emerald)'};">
        ${s.warning ? '🚨 0 skips left' : `🛡️ ${s.safeMissesLeft} skips left`}
      </span>
    </button>
  `).join('') || '<div style="font-size: 12px; color: var(--text-muted);">Enroll courses to see attendance safety metrics.</div>';

  // Mark all today present button
  const markAllBtn = document.getElementById('btn-mark-all-today');
  markAllBtn.onclick = async () => {
    if (!dashboardData.classes.length) return;
    const today = dashboardData.date;
    for (const c of dashboardData.classes) {
      await api('/attendance', 'POST', { subjectId: c.subjectId, slotId: c.slotId, date: today, status: 'present' }).catch(() => {});
    }
    triggerConfetti();
    await refreshAllData();
  };

  // Today's Classes List
  const classList = document.getElementById('dash-classes-list');
  classList.innerHTML = (dashboardData.classes || []).map(c => `
    <div class="card dashboard-class-row" style="padding: 14px 18px; margin-bottom: 10px; display: flex; align-items: center; justify-content: space-between;">
      <button type="button" class="dashboard-class-open" onclick="openClassDetails(${c.slotId})" aria-label="Open ${c.code} class details">
        <span style="width: 4px; height: 36px; flex: 0 0 4px; border-radius: 4px; background: ${c.color};"></span>
        <div>
          <div style="font-size: 14px; font-weight: 800;">${c.code} · ${c.title}</div>
          <div style="font-size: 11px; color: var(--text-muted);">${formatClock(c.startTime)} – ${formatClock(c.endTime)} · ${c.room || 'Classroom'}</div>
        </div>
      </button>
      <div style="display: flex; gap: 6px;">
        <button class="pill-btn" style="padding: 4px 10px; font-size: 11px; color: var(--emerald);" onclick="quickMarkAttendance(${c.subjectId}, ${c.slotId}, 'present')">Present</button>
        <button class="pill-btn" style="padding: 4px 10px; font-size: 11px; color: var(--amber);" onclick="quickMarkAttendance(${c.subjectId}, ${c.slotId}, 'late')">Late</button>
      </div>
    </div>
  `).join('') || '<div class="card dashboard-empty-state">No classes today. Enjoy your day!</div>';

  // Deadlines List
  const dueList = document.getElementById('dash-deadlines-list');
  dueList.innerHTML = (dashboardData.dueSoon || []).map(w => `
    <div class="card" style="padding: 14px 18px; margin-bottom: 10px; display: flex; align-items: center; justify-content: space-between;">
      <div>
        <div style="font-size: 14px; font-weight: 700;">${w.title}</div>
        <div style="font-size: 11px; color: var(--text-muted);">${w.subjectCode || 'General'} · ${w.type.toUpperCase()}</div>
      </div>
      <div class="badge" style="background: ${w.overdue ? 'var(--rose)' : 'var(--primary)'}; font-size: 10px;">
        ${w.overdue ? 'Overdue' : formatDue(w.dueAt)}
      </div>
    </div>
  `).join('') || '<div class="card dashboard-empty-state">No urgent deadlines in the next 7 days.</div>';

  // Tasks counter
  const pendingTasks = schoolWorks.filter(w => w.status !== 'done').length;
  document.getElementById('sidebar-tasks-badge').textContent = pendingTasks;
}

// ============================================================================
// 2. Schedule Render
// ============================================================================
let currentSchedView = 'week';
let currentScheduleDate = new Date();
const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const WEEK_ORDER = [1, 2, 3, 4, 5, 6, 0];

function renderSchedule() {
  const container = document.getElementById('schedule-container');
  renderWeeklyPlan();
  if (currentSchedView === 'week') {
    container.innerHTML = `
      <div class="schedule-week-grid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 14px;">
        ${WEEK_ORDER.map(d => {
          const daySlots = scheduleSlots.filter(s => s.dayOfWeek === d);
          return `
            <div class="card" style="padding: 16px;">
              <div style="font-size: 14px; font-weight: 800; margin-bottom: 12px; color: var(--primary);">${DAY_NAMES[d]}</div>
              ${daySlots.map(s => `
                <div style="padding: 10px; border-radius: 10px; background: rgba(255,255,255,0.03); border: 1px solid var(--border-color); margin-bottom: 8px;">
                  <div style="font-size: 12px; font-weight: 800; color: ${s.color};">${s.subjectCode}</div>
                  <div style="font-size: 11px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${s.subjectTitle}</div>
                  <div style="font-size: 10px; color: var(--text-muted); margin-top: 4px;">${formatClock(s.startTime)} - ${formatClock(s.endTime)}</div>
                  <div style="font-size: 9px; color: var(--text-dim);">${s.room || s.modality || ''}</div>
                </div>
              `).join('') || '<div style="font-size: 11px; color: var(--text-dim);">No classes</div>'}
            </div>
          `;
        }).join('')}
      </div>
    `;
    return;
  }

  const dayIndex = currentScheduleDate.getDay();
  const daySlots = scheduleSlots
    .filter(slot => slot.dayOfWeek === dayIndex)
    .sort((a, b) => a.startTime.localeCompare(b.startTime));
  const dateLabel = currentScheduleDate.toLocaleDateString(undefined, {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  container.innerHTML = `
    <div class="schedule-day-view">
      <div class="schedule-day-toolbar">
        <button type="button" class="icon-btn" aria-label="Previous day" title="Previous day" onclick="shiftScheduleDay(-1)">‹</button>
        <div class="schedule-day-heading">
          <h3>${DAY_NAMES[dayIndex]}</h3>
          <span>${dateLabel}</span>
        </div>
        <button type="button" class="icon-btn" aria-label="Next day" title="Next day" onclick="shiftScheduleDay(1)">›</button>
        <button type="button" class="pill-btn" onclick="goToToday()">Today</button>
      </div>
      <div class="schedule-day-list">
        ${daySlots.map(slot => `
          <article class="schedule-day-class">
            <div class="schedule-day-time">${formatClock(slot.startTime)} – ${formatClock(slot.endTime)}</div>
            <div class="schedule-day-course" style="--course-color: ${slot.color};">
              <strong>${slot.subjectCode}</strong>
              <span>${slot.subjectTitle}</span>
              <small>${slot.room || slot.modality || 'Location not set'}</small>
            </div>
          </article>
        `).join('') || '<p class="schedule-day-empty">No classes scheduled for this day.</p>'}
      </div>
    </div>
  `;
}

function localDateKey(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function renderWeeklyPlan() {
  const container = document.getElementById('weekly-plan-list');
  if (!container) return;

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const planDays = Array.from({ length: 7 }, (_, offset) => {
    const date = new Date(today);
    date.setDate(date.getDate() + offset);
    const dateKey = localDateKey(date);
    const events = [];

    scheduleSlots
      .filter(slot => slot.dayOfWeek === date.getDay())
      .forEach(slot => events.push({
        time: slot.startTime,
        label: `${slot.subjectCode} · ${slot.subjectTitle}`,
        meta: `${formatClock(slot.startTime)} · Class`,
      }));

    schoolWorks
      .filter(work => work.status !== 'done' && work.dueAt && localDateKey(new Date(work.dueAt)) === dateKey)
      .forEach(work => {
        const due = new Date(work.dueAt);
        const time = `${String(due.getHours()).padStart(2, '0')}:${String(due.getMinutes()).padStart(2, '0')}`;
        events.push({
          time,
          label: work.title,
          meta: `${due.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })} · Due`,
        });
      });

    events.sort((a, b) => a.time.localeCompare(b.time));
    const heading = offset === 0
      ? 'Today'
      : offset === 1
        ? 'Tomorrow'
        : date.toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' });

    return `
      <article class="weekly-plan-day">
        <h4>${heading}</h4>
        ${events.map(item => `
          <div class="weekly-plan-event">
            <time>${escapeHtml(item.meta.split(' · ')[0])}</time>
            <span>${escapeHtml(item.label)} <small>${escapeHtml(item.meta.split(' · ')[1])}</small></span>
          </div>
        `).join('') || '<p class="weekly-plan-no-events">Nothing planned</p>'}
      </article>
    `;
  });

  const hasEvents = planDays.some((_, index) => {
    const date = new Date(today);
    date.setDate(date.getDate() + index);
    return scheduleSlots.some(slot => slot.dayOfWeek === date.getDay()) ||
      schoolWorks.some(work => work.status !== 'done' && work.dueAt && localDateKey(new Date(work.dueAt)) === localDateKey(date));
  });

  container.innerHTML = hasEvents
    ? planDays.join('')
    : '<p class="weekly-plan-empty">Nothing scheduled or due this week. Enjoy the breathing room!</p>';
}

function setScheduleView(v) {
  if (!['week', 'day'].includes(v)) return;
  currentSchedView = v;
  document.getElementById('btn-view-week').classList.toggle('active', v === 'week');
  document.getElementById('btn-view-day').classList.toggle('active', v === 'day');
  renderSchedule();
}

function shiftScheduleDay(offset) {
  currentScheduleDate.setDate(currentScheduleDate.getDate() + offset);
  renderSchedule();
}

function goToToday() {
  currentScheduleDate = new Date();
  renderSchedule();
}

function exportScheduleClipboard() {
  const lines = ['📅 ClassMate Weekly Schedule\n'];
  for (const d of WEEK_ORDER) {
    const slots = scheduleSlots.filter(s => s.dayOfWeek === d);
    if (!slots.length) continue;
    lines.push(`\n${DAY_NAMES[d].toUpperCase()}:`);
    for (const s of slots) {
      lines.push(`  • ${formatClock(s.startTime)} – ${formatClock(s.endTime)}: ${s.subjectCode} (${s.subjectTitle}) [${s.room || s.modality || 'Class'}]`);
    }
  }
  navigator.clipboard.writeText(lines.join('\n'));
  showToast('Timetable copied to clipboard! Ready to share or save. 📋✨');
}

// ============================================================================
// 3. Attendance Render
// ============================================================================
function renderAttendance() {
  const container = document.getElementById('attendance-course-cards');
  const atRiskCount = attendanceSummary.filter(s => s.warning).length;

  const banner = document.getElementById('attendance-overall-banner');
  const bannerText = document.getElementById('attendance-overall-text');
  if (atRiskCount > 0) {
    banner.style.background = 'var(--grad-warning)';
    bannerText.textContent = `Warning: ${atRiskCount} course(s) are at or approaching the maximum allowable absence limit!`;
  } else {
    banner.style.background = 'var(--grad-success)';
    bannerText.textContent = 'All courses are within safe absence thresholds. You are in good standing! 🛡️';
  }

  container.innerHTML = attendanceSummary.map(s => `
    <div class="card" id="attendance-course-${s.subjectId}" tabindex="-1" style="margin-bottom: 16px;">
      <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px; margin-bottom: 14px;">
        <div style="display: flex; align-items: center; gap: 12px;">
          <div style="width: 12px; height: 12px; border-radius: 50%; background: ${s.color};"></div>
          <div>
            <div style="font-size: 16px; font-weight: 800;">${s.code} · ${s.title}</div>
            <div style="font-size: 11.5px; color: var(--text-muted);">${s.counted} class sessions recorded</div>
          </div>
        </div>
        <div class="badge" style="background: ${s.warning ? 'var(--rose)' : 'var(--emerald)'}; font-size: 12px; padding: 5px 12px;">
          ${s.warning ? '🚨 0 Skips Left (Cutoff)' : `🛡️ ${s.safeMissesLeft} Safe Skips Left`}
        </div>
      </div>

      <!-- Attendance Rate Bar -->
      <div style="display: flex; align-items: center; gap: 14px; margin-bottom: 14px;">
        <div style="flex: 1; height: 10px; background: rgba(255,255,255,0.06); border-radius: 10px; overflow: hidden;">
          <div style="height: 100%; width: ${s.attendanceRate || 100}%; background: ${s.warning ? 'var(--rose)' : 'var(--emerald)'}; border-radius: 10px; transition: width 0.6s ease;"></div>
        </div>
        <span style="font-size: 15px; font-weight: 800; color: ${s.warning ? 'var(--rose)' : 'var(--emerald)'};">${s.attendanceRate || 100}%</span>
      </div>

      <!-- Status Counts & 1-tap Buttons -->
      <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px;">
        <div style="display: flex; gap: 8px;">
          <span class="pill-btn" style="cursor: default;">${s.present} Present</span>
          <span class="pill-btn" style="cursor: default; color: var(--rose);">${s.absent} Absent</span>
          <span class="pill-btn" style="cursor: default; color: var(--amber);">${s.late} Late</span>
        </div>
        <div style="display: flex; gap: 8px;">
          <button class="pill-btn" style="color: var(--emerald);" onclick="quickMarkAttendance(${s.subjectId}, null, 'present')">+ Present</button>
          <button class="pill-btn" style="color: var(--rose);" onclick="quickMarkAttendance(${s.subjectId}, null, 'absent')">+ Absent</button>
          <button class="pill-btn" style="color: var(--amber);" onclick="quickMarkAttendance(${s.subjectId}, null, 'late')">+ Late</button>
        </div>
      </div>
    </div>
  `).join('') || '<div class="card" style="padding: 32px; text-align: center; color: var(--text-muted);">No enrolled courses to track attendance.</div>';
}

async function quickMarkAttendance(subjectId, slotId, status) {
  const now = new Date();
  const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  try {
    const result = await api('/attendance', 'POST', { subjectId, slotId, date: dateStr, status });
    await refreshAllData();
    showToast(`Logged attendance as ${status.toUpperCase()}! ✅`, false, {
      label: 'Undo',
      onClick: () => undoAttendanceEntry(result.data.id),
    });
  } catch (e) {
    showToast(e.message, true);
  }
}

async function undoAttendanceEntry(id) {
  try {
    await api(`/attendance/${id}`, 'DELETE');
    await refreshAllData();
    showToast('Attendance entry undone.');
  } catch (error) {
    showToast(error.message, true);
  }
}

let selectedClassDetails = null;

function openClassDetails(slotId) {
  selectedClassDetails = dashboardData?.classes?.find(item => item.slotId === slotId);
  if (!selectedClassDetails) return;

  document.getElementById('class-detail-code').textContent = selectedClassDetails.code;
  document.getElementById('class-detail-title').textContent = selectedClassDetails.title;
  document.getElementById('class-detail-time').textContent = `${formatClock(selectedClassDetails.startTime)} – ${formatClock(selectedClassDetails.endTime)}`;
  document.getElementById('class-detail-location').textContent = selectedClassDetails.room || selectedClassDetails.modality || 'Location not set';
  document.getElementById('class-detail-date').textContent = dashboardData.date;
  document.getElementById('class-detail-modal').classList.add('open');
}

async function markSelectedClass(status) {
  if (!selectedClassDetails) return;
  await quickMarkAttendance(selectedClassDetails.subjectId, selectedClassDetails.slotId, status);
  closeModal('class-detail-modal');
}

function openSelectedClassAttendance() {
  if (!selectedClassDetails) return;
  const subjectId = selectedClassDetails.subjectId;
  closeModal('class-detail-modal');
  openAttendanceSubject(subjectId);
}

function openSelectedClassTimetable() {
  if (!selectedClassDetails) return;
  currentScheduleDate = new Date(`${dashboardData.date}T12:00:00`);
  closeModal('class-detail-modal');
  switchView('schedule');
  setScheduleView('day');
}

function openAttendanceSubject(subjectId) {
  switchView('attendance');
  const courseCard = document.getElementById(`attendance-course-${subjectId}`);
  if (courseCard) {
    courseCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
    courseCard.focus({ preventScroll: true });
  }
}

// ============================================================================
// 4. Tasks & Works Render
// ============================================================================
let currentTaskFilter = 'all';

function renderTasks() {
  const container = document.getElementById('tasks-list-container');
  const search = (document.getElementById('task-search-input')?.value || '').toLowerCase();

  const filtered = schoolWorks.filter(w => {
    if (currentTaskFilter !== 'all' && w.status !== currentTaskFilter) return false;
    if (search && !w.title.toLowerCase().contains(search)) return false;
    return true;
  });

  container.innerHTML = filtered.map(w => {
    const isDone = w.status === 'done';
    const attachments = workAttachments.filter(file => file.resourceId === w.id);
    return `
      <div class="task-item ${isDone ? 'done' : ''}">
        <div class="task-status-control">
          <button type="button" class="custom-checkbox" aria-label="Choose task status" aria-haspopup="true" aria-expanded="false" onclick="toggleTaskStatus(event, ${w.id})">
            ${isDone ? '✓' : w.status === 'doing' ? '↻' : ''}
          </button>
          <div class="task-status-menu" role="group" aria-label="Task status choices" hidden>
            <button type="button" class="task-status-option ${w.status === 'todo' ? 'active' : ''}" aria-pressed="${w.status === 'todo'}" onclick="setTaskStatus(${w.id}, 'todo')">To Do</button>
            <button type="button" class="task-status-option ${w.status === 'doing' ? 'active' : ''}" aria-pressed="${w.status === 'doing'}" onclick="setTaskStatus(${w.id}, 'doing')">In Progress</button>
            <button type="button" class="task-status-option ${w.status === 'done' ? 'active' : ''}" aria-pressed="${w.status === 'done'}" onclick="setTaskStatus(${w.id}, 'done')">Completed</button>
          </div>
        </div>
        <div class="task-item-details" style="flex: 1;">
          <div class="task-title" style="font-size: 14.5px; font-weight: 700;">${w.title}</div>
          <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">
            ${w.subjectCode || 'General'} · ${w.type.toUpperCase()} · ${w.priority === 'high' ? '🔥 Urgent' : w.priority}
          </div>
          ${renderAttachmentControls(attachments)}
        </div>
        ${w.dueAt ? `<div class="badge" style="background: ${w.overdue ? 'var(--rose)' : 'var(--primary)'}; font-size: 10px;">${formatDue(w.dueAt)}</div>` : ''}
        <button type="button" class="pill-btn task-attach-button" onclick="chooseTaskAttachments(${w.id})">+ Files</button>
        <button class="icon-btn" style="width: 30px; height: 30px;" onclick="deleteTask(${w.id})">🗑️</button>
      </div>
    `;
  }).join('') || '<div class="card" style="padding: 40px; text-align: center; color: var(--text-muted);">No school works match your filter.</div>';
}

function filterTaskStatus(status) {
  currentTaskFilter = status;
  document.querySelectorAll('[data-filter]').forEach(b => b.classList.toggle('active', b.dataset.filter === status));
  renderTasks();
}

function filterTasks() {
  renderTasks();
}

function toggleTaskStatus(event, id) {
  const button = event.currentTarget;
  const menu = button.nextElementSibling;
  const shouldOpen = menu.hidden;

  document.querySelectorAll('.task-status-menu:not([hidden])').forEach(openMenu => {
    openMenu.hidden = true;
    openMenu.previousElementSibling.setAttribute('aria-expanded', 'false');
  });

  menu.hidden = !shouldOpen;
  button.setAttribute('aria-expanded', String(shouldOpen));
}

async function setTaskStatus(id, nextStatus) {
  const currentWork = schoolWorks.find(work => work.id === id);
  try {
    await api(`/works/${id}/status`, 'PATCH', { status: nextStatus });
    if (nextStatus === 'done' && currentWork?.status !== 'done') {
      triggerConfetti();
      showToast('Assignment completed! Great work! 🎉');
    } else {
      const labels = { todo: 'To Do', doing: 'In Progress', done: 'Completed' };
      showToast(`Task status changed to ${labels[nextStatus]}.`);
    }
    await refreshAllData();
  } catch (e) {
    showToast(e.message, true);
  }
}

async function deleteTask(id) {
  if (!confirm('Move this task to the Recycle Bin? You can restore it for 30 days.')) return;
  try {
    const result = await api(`/works/${id}`, 'DELETE');
    await refreshAllData();
    showToast('Task moved to Recycle Bin.', false, {
      label: 'Undo',
      onClick: () => undoRecycleBinEntry(result.data.recycleBinId),
    });
  } catch (error) {
    showToast(error.message, true);
  }
}

// ============================================================================
// 5. Pomodoro Focus Zone & Ambient Sound Synthesizer
// ============================================================================
function setTimerMode(mode, targetBtn) {
  if (isTimerRunning) {
    clearInterval(timerInterval);
    timerInterval = null;
    isTimerRunning = false;
    timerEndsAt = null;
    document.getElementById('btn-timer-toggle').textContent = '▶ Start Focus';
  }
  timerMode = mode;
  document.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
  if (targetBtn) targetBtn.classList.add('active');
  else if (typeof event !== 'undefined' && event?.target) event.target.classList.add('active');

  if (mode === 'focus') timerTotalSeconds = 25 * 60;
  else if (mode === 'short') timerTotalSeconds = 5 * 60;
  else if (mode === 'long') timerTotalSeconds = 15 * 60;

  timerRemainingSeconds = timerTotalSeconds;
  updateTimerDisplay();
}

function toggleTimer() {
  if (isTimerRunning) {
    clearInterval(timerInterval);
    isTimerRunning = false;
    timerEndsAt = null;
    document.getElementById('btn-timer-toggle').textContent = '▶ Resume Focus';
  } else {
    isTimerRunning = true;
    timerEndsAt = Date.now() + timerRemainingSeconds * 1000;
    document.getElementById('btn-timer-toggle').textContent = '⏸ Pause';
    timerInterval = setInterval(tickFocusTimer, 1000);
  }
}

function tickFocusTimer() {
  if (!isTimerRunning || !timerEndsAt) return;
  timerRemainingSeconds = Math.max(0, Math.ceil((timerEndsAt - Date.now()) / 1000));
  updateTimerDisplay();
  if (timerRemainingSeconds === 0) {
    clearInterval(timerInterval);
    timerInterval = null;
    isTimerRunning = false;
    timerEndsAt = null;
    document.getElementById('btn-timer-toggle').textContent = '▶ Start Focus';
    onPomodoroComplete();
  }
}

function resetTimer() {
  clearInterval(timerInterval);
  timerInterval = null;
  isTimerRunning = false;
  timerEndsAt = null;
  timerRemainingSeconds = timerTotalSeconds;
  document.getElementById('btn-timer-toggle').textContent = '▶ Start Focus';
  updateTimerDisplay();
}

function updateTimerDisplay() {
  const mins = String(Math.floor(timerRemainingSeconds / 60)).padStart(2, '0');
  const secs = String(timerRemainingSeconds % 60).padStart(2, '0');
  document.getElementById('timer-display').textContent = `${mins}:${secs}`;

  // SVG Progress Ring
  const progress = 1 - (timerRemainingSeconds / timerTotalSeconds);
  const offset = 785 * (1 - progress);
  const circle = document.getElementById('timer-circle-progress');
  if (circle) circle.style.strokeDashoffset = offset;
}

async function onPomodoroComplete() {
  triggerConfetti();
  const minutes = Math.round(timerTotalSeconds / 60);
  const subId = document.getElementById('timer-subject-select').value || null;
  showBrowserNotification(
    timerMode === 'focus' ? 'Focus session complete' : 'Break is over',
    timerMode === 'focus' ? `You focused for ${minutes} minutes. Time for a short break!` : 'Ready when you are for another focus session.',
    'classmate-focus-timer',
  );

  try {
    await api('/study/sessions', 'POST', {
      subjectId: subId ? Number(subId) : null,
      durationMinutes: minutes,
      mode: timerMode,
      notes: `Completed ${timerMode} session`,
    });
    showToast(`Session Complete! +${minutes} XP awarded to your Scholar Rank! 🎉`);
    await refreshAllData();
  } catch (e) {
    console.error('Could not save the completed focus session:', e);
    showToast('Could not save your focus session. Check your connection and try again.', true);
  }
}

function renderFocus() {
  if (studyStats) {
    document.getElementById('focus-streak-val').textContent = `${studyStats.streakDays} Days`;
    document.getElementById('focus-today-val').textContent = `${studyStats.totalMinutesToday}m`;
    document.getElementById('focus-week-val').textContent = `${studyStats.totalMinutesThisWeek}m`;
    document.getElementById('focus-sessions-val').textContent = `${studyStats.totalSessionsAllTime}`;
  }

  const history = document.getElementById('focus-history-list');
  history.innerHTML = studySessions.slice(0, 5).map(s => `
    <div style="display: flex; align-items: center; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid var(--border-color);">
      <div>
        <div style="font-size: 13px; font-weight: 700;">${s.subjectCode || 'Deep Focus Session'}</div>
        <div style="font-size: 11px; color: var(--text-muted);">${s.notes || 'Focus work logged'}</div>
      </div>
      <span class="badge" style="background: var(--primary-medium); color: var(--primary);">${s.durationMinutes}m</span>
    </div>
  `).join('') || '<div style="font-size: 12px; color: var(--text-muted); padding: 12px 0;">No completed study sessions yet today.</div>';
}

// ============================================================================
// Web Audio Ambient Synthesizer
// ============================================================================
function initVisualizer() {
  const box = document.getElementById('waveform-box');
  if (!box) return;
  box.innerHTML = Array.from({ length: 24 }).map((_, i) =>
    `<div class="wave-bar" id="wb-${i}"></div>`
  ).join('');
}

function setSoundscape(sound) {
  currentSoundscape = sound;
  document.querySelectorAll('.sound-pill').forEach(p => p.classList.remove('active'));
  event.target.classList.add('active');

  if (isAmbientActive) {
    stopAmbientAudio();
    startAmbientAudio();
  }
}

function toggleAmbientAudio(active) {
  isAmbientActive = active;
  const box = document.getElementById('waveform-box');
  if (active) {
    startAmbientAudio();
    if (box) box.classList.add('active');
  } else {
    stopAmbientAudio();
    if (box) box.classList.remove('active');
  }
}

function startAmbientAudio() {
  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!audioCtx) audioCtx = new AudioContext();
    if (audioCtx.state === 'suspended') audioCtx.resume();

    ambientGain = audioCtx.createGain();
    ambientGain.gain.setValueAtTime(0.08, audioCtx.currentTime);

    // Procedural Pink Noise Synthesizer (Rainfall / Cafe ambience)
    const bufferSize = audioCtx.sampleRate * 2;
    const noiseBuffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
    const output = noiseBuffer.getChannelData(0);
    let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;

    for (let i = 0; i < bufferSize; i++) {
      const white = Math.random() * 2 - 1;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      output[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11;
      b6 = white * 0.115926;
    }

    const whiteNoise = audioCtx.createBufferSource();
    whiteNoise.buffer = noiseBuffer;
    whiteNoise.loop = true;

    // Filter frequency tailored to soundscape
    const filter = audioCtx.createBiquadFilter();
    filter.type = 'lowpass';
    if (currentSoundscape === 'rain') filter.frequency.setValueAtTime(800, audioCtx.currentTime);
    else if (currentSoundscape === 'cafe') filter.frequency.setValueAtTime(450, audioCtx.currentTime);
    else if (currentSoundscape === 'forest') filter.frequency.setValueAtTime(1200, audioCtx.currentTime);
    else filter.frequency.setValueAtTime(600, audioCtx.currentTime);

    whiteNoise.connect(filter);
    filter.connect(ambientGain);
    ambientGain.connect(audioCtx.destination);
    whiteNoise.start();
    ambientNoiseNode = whiteNoise;
  } catch (e) {
    console.warn('Web Audio Ambient Synthesizer initialized.');
  }
}

function stopAmbientAudio() {
  if (ambientNoiseNode) {
    try { ambientNoiseNode.stop(); } catch (_) {}
    ambientNoiseNode = null;
  }
}

// ============================================================================
// 6. Courses & GPA Target Solver
// ============================================================================
let solverSubjectId = null;

function renderGrades() {
  if (gradesSummary) {
    document.getElementById('gpa-large-val').textContent = gradesSummary.cumulativeGpa ? `${gradesSummary.cumulativeGpa.toFixed(2)} / 4.00` : '3.85 / 4.00';
    document.getElementById('header-gpa-text').textContent = gradesSummary.cumulativeGpa ? `GPA ${gradesSummary.cumulativeGpa.toFixed(2)}` : 'GPA 3.85';
    document.getElementById('gpa-standing-text').textContent = `${gradesSummary.academicStanding} · ${gradesSummary.totalUnitsCounted || 12} Units Counted`;
  }

  const container = document.getElementById('courses-cards-container');
  container.innerHTML = subjects.map(s => `
    <div class="card" style="margin-bottom: 16px;">
      <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px;">
        <div style="display: flex; align-items: center; gap: 12px;">
          <div style="width: 38px; height: 38px; border-radius: 10px; background: ${s.color}; color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 800;">
            ${s.code[0] || 'C'}
          </div>
          <div>
            <div style="font-size: 16px; font-weight: 800;">${s.code} · ${s.title}</div>
            <div style="font-size: 12px; color: var(--text-muted);">${s.instructor || 'Prof'} · ${s.units || 3} Units</div>
          </div>
        </div>
        <div style="display: flex; gap: 8px;">
          <button class="pill-btn" onclick="openNewNoteModal(${s.id})">📝 Flashnotes</button>
          <button class="pill-btn" onclick="openGpaSolverForSubject(${s.id})">🎯 Target Solver</button>
        </div>
      </div>
    </div>
  `).join('');
}

function updateGpaSimulation(val) {
  const target = Number(val);
  const summary = gradesSummary?.subjects?.find(item => item.subjectId === solverSubjectId);
  const letter = target >= 93 ? 'A' : target >= 90 ? 'A-' : target >= 87 ? 'B+' : target >= 83 ? 'B' : target >= 80 ? 'B-' : target >= 77 ? 'C+' : target >= 73 ? 'C' : target >= 70 ? 'C-' : 'D';
  document.getElementById('slider-target-val').textContent = `${target}% (${letter})`;

  if (!summary) {
    document.getElementById('simulation-output-text').textContent = 'Choose a course to calculate the score needed on its remaining work.';
    return;
  }

  const gradedComponents = summary.components.filter(component => component.scorePct !== null && component.scorePct !== undefined);
  const gradedWeight = gradedComponents.reduce((total, component) => total + component.weightPct, 0);
  const earnedWeight = gradedComponents.reduce((total, component) => total + (component.scorePct * component.weightPct) / 100, 0);
  const remainingWeight = Math.max(0, 100 - gradedWeight);

  if (remainingWeight === 0) {
    const currentGrade = Math.round(earnedWeight * 10) / 10;
    document.getElementById('simulation-output-text').textContent =
      `${summary.code} has no ungraded course weight remaining. Its calculated course grade is ${currentGrade}%.`;
    return;
  }

  const needed = ((target - earnedWeight) / remainingWeight) * 100;
  let result;
  if (needed <= 0) {
    result = `${summary.code} has already met the ${target}% target based on recorded grades.`;
  } else if (needed > 100) {
    result = `${summary.code} would need ${needed.toFixed(1)}% across the remaining ${remainingWeight}% of course work, which is above 100%.`;
  } else {
    result = `You need ${needed.toFixed(1)}% across the remaining ${remainingWeight}% of ${summary.code} to finish at ${target}%.`;
  }
  document.getElementById('simulation-output-text').textContent = result;
}

function openGpaSolverForSubject(id) {
  solverSubjectId = Number(id);
  const summary = gradesSummary?.subjects?.find(item => item.subjectId === solverSubjectId);
  switchView('grades');
  document.getElementById('solver-subject-label').textContent = summary ? `· ${summary.code}` : '';
  const target = summary?.targetPercentage ?? 85;
  const slider = document.getElementById('gpa-target-slider');
  slider.value = Math.max(Number(slider.min), Math.min(Number(slider.max), target));
  updateGpaSimulation(slider.value);
  requestAnimationFrame(() => document.getElementById('gpa-solver-card').scrollIntoView({ behavior: 'smooth', block: 'center' }));
}

// ============================================================================
// 7. Flashnotes
// ============================================================================
function renderNotes() {
  const grid = document.getElementById('notes-grid');
  const search = (document.getElementById('notes-search-input')?.value || '').toLowerCase();
  const dueCount = getDueReviewNotes().length;
  const dueCountLabel = document.getElementById('review-due-count');
  if (dueCountLabel) dueCountLabel.textContent = dueCount;
  const reviewButton = document.getElementById('btn-review-notes');
  if (reviewButton) reviewButton.disabled = dueCount === 0;

  const filtered = notesList.filter(n => {
    if (!search) return true;
    return n.title.toLowerCase().includes(search) || n.content.toLowerCase().includes(search);
  });

  grid.innerHTML = filtered.map(n => `
    <article class="card note-card">
      <div class="note-card-heading">
        ${n.subjectCode ? `<span class="badge note-course-badge">${escapeHtml(n.subjectCode)}</span>` : '<span></span>'}
        <div class="note-card-meta">
          ${n.isPinned ? '<span class="note-pinned-label">📌 Pinned</span>' : ''}
          ${noteAttachments.some(file => file.resourceId === n.id) ? `<span class="note-attachment-count">📎 ${noteAttachments.filter(file => file.resourceId === n.id).length}</span>` : ''}
        </div>
      </div>
      <button type="button" class="note-open-button" onclick="openNoteDetails(${n.id})" aria-label="Open note: ${escapeHtml(n.title)}">
        <h4>${escapeHtml(n.title)}</h4>
        <p>${escapeHtml(n.content.slice(0, 220))}${n.content.length > 220 ? '…' : ''}</p>
      </button>
      ${n.tags ? `<div class="note-card-tags">#${escapeHtml(n.tags.split(',').map(tag => tag.trim()).join(' #'))}</div>` : ''}
      <div class="note-card-actions">
        <button type="button" class="pill-btn" onclick="toggleNotePin(${n.id})">${n.isPinned ? 'Unpin' : '📌 Pin'}</button>
        <button type="button" class="icon-btn" title="Move note to Recycle Bin" aria-label="Delete ${escapeHtml(n.title)}" onclick="deleteNote(${n.id})">🗑️</button>
      </div>
    </article>
  `).join('') || '<div class="card" style="grid-column: 1/-1; padding: 40px; text-align: center; color: var(--text-muted);">No study flashnotes found. Tap "+ New Flashnote" to write one!</div>';
}

function filterNotes() {
  renderNotes();
}

function openNoteDetails(id) {
  const note = notesList.find(item => item.id === id);
  if (!note) return;
  activeNoteId = id;
  reviewAnswerVisible = false;
  document.getElementById('note-reader-course').textContent = note.subjectCode || 'General';
  document.getElementById('note-reader-title').textContent = note.title;
  document.getElementById('note-reader-content').textContent = note.content;
  document.getElementById('note-reader-content').hidden = activeReviewMode;
  document.getElementById('note-reader-tags').textContent = note.tags
    ? `#${note.tags.split(',').map(tag => tag.trim()).join(' #')}`
    : '';
  const attachments = noteAttachments.filter(file => file.resourceId === note.id);
  document.getElementById('note-reader-attachments').innerHTML = attachments.length
    ? renderAttachmentControls(attachments)
    : '<p class="attachment-empty">No files attached yet.</p>';
  document.getElementById('note-review-controls').hidden = !activeReviewMode;
  document.getElementById('note-review-reveal').hidden = !activeReviewMode;
  document.getElementById('note-review-ratings').hidden = true;
  document.querySelector('.note-reader-actions').hidden = activeReviewMode;
  const pinButton = document.getElementById('note-reader-pin');
  pinButton.textContent = note.isPinned ? 'Unpin' : '📌 Pin';
  pinButton.setAttribute('aria-label', note.isPinned ? 'Unpin note' : 'Pin note');
  document.getElementById('note-reader-modal').classList.add('open');
}

function noteReviewStorageKey() {
  const identity = currentUser?.id ?? currentUser?.email ?? 'student';
  return `classmate_note_reviews_${encodeURIComponent(identity)}`;
}

function getNoteReviewState() {
  const saved = localStorage.getItem(noteReviewStorageKey());
  if (!saved) return {};
  try {
    return JSON.parse(saved);
  } catch (error) {
    console.warn('Could not read flashnote review schedule:', error);
    return {};
  }
}

function getDueReviewNotes() {
  const reviewState = getNoteReviewState();
  const now = Date.now();
  return notesList
    .filter(note => !reviewState[note.id] || new Date(reviewState[note.id]).getTime() <= now)
    .sort((a, b) => {
      const aDue = reviewState[a.id] ? new Date(reviewState[a.id]).getTime() : 0;
      const bDue = reviewState[b.id] ? new Date(reviewState[b.id]).getTime() : 0;
      return aDue - bDue;
    });
}

function startNoteReview() {
  reviewQueue = getDueReviewNotes().map(note => note.id);
  if (!reviewQueue.length) {
    showToast('You are all caught up on flashnote reviews.');
    return;
  }
  activeReviewMode = true;
  openNextReviewNote();
}

function openNextReviewNote() {
  const nextId = reviewQueue.shift();
  if (nextId === undefined) {
    activeReviewMode = false;
    closeModal('note-reader-modal');
    renderNotes();
    showToast('Review session complete. Nice work!');
    return;
  }
  openNoteDetails(nextId);
}

function revealNoteAnswer() {
  if (!activeReviewMode) return;
  reviewAnswerVisible = true;
  document.getElementById('note-reader-content').hidden = false;
  document.getElementById('note-review-reveal').hidden = true;
  document.getElementById('note-review-ratings').hidden = false;
}

function rateCurrentNote(rating) {
  if (!activeReviewMode || !activeNoteId) return;
  const intervals = { again: 10 * 60 * 1000, good: 24 * 60 * 60 * 1000, easy: 4 * 24 * 60 * 60 * 1000 };
  const interval = intervals[rating];
  if (!interval || !reviewAnswerVisible) return;

  const reviewState = getNoteReviewState();
  reviewState[activeNoteId] = new Date(Date.now() + interval).toISOString();
  try {
    localStorage.setItem(noteReviewStorageKey(), JSON.stringify(reviewState));
  } catch (error) {
    showToast('Could not save review progress on this device.', true);
    console.error('Could not save flashnote review schedule:', error);
    return;
  }
  openNextReviewNote();
}

async function toggleNotePin(id) {
  const note = notesList.find(item => item.id === id);
  if (!note) return;
  try {
    await api(`/notes/${id}`, 'PUT', { isPinned: !note.isPinned });
    await refreshAllData();
    if (activeNoteId === id) openNoteDetails(id);
    showToast(note.isPinned ? 'Flashnote unpinned.' : 'Flashnote pinned.');
  } catch (error) {
    showToast(error.message, true);
  }
}

function toggleCurrentNotePin() {
  if (activeNoteId !== null) toggleNotePin(activeNoteId);
}

function editCurrentNote() {
  const note = notesList.find(item => item.id === activeNoteId);
  if (!note) return;
  activeReviewMode = false;
  closeModal('note-reader-modal');
  openNewNoteModal(note.subjectId);
  editingNoteId = note.id;
  document.getElementById('note-modal-title').textContent = 'Edit Flashnote';
  document.getElementById('note-submit-button').textContent = 'Save Changes';
  document.getElementById('note-input-title').value = note.title;
  document.getElementById('note-input-content').value = note.content;
  document.getElementById('note-input-tags').value = note.tags || '';
}

function deleteCurrentNote() {
  if (activeNoteId !== null) deleteNote(activeNoteId, true);
}

async function deleteNote(id, fromReader = false) {
  const note = notesList.find(item => item.id === id);
  if (!note || !confirm(`Move "${note.title}" to the Recycle Bin? You can restore it for 30 days.`)) return;
  try {
    const result = await api(`/notes/${id}`, 'DELETE');
    if (fromReader) {
      activeReviewMode = false;
      closeModal('note-reader-modal');
    }
    activeNoteId = null;
    await refreshAllData();
    showToast('Flashnote moved to Recycle Bin.', false, {
      label: 'Undo',
      onClick: () => undoRecycleBinEntry(result.data.recycleBinId),
    });
  } catch (error) {
    showToast(error.message, true);
  }
}

function renderRecycleBin() {
  const list = document.getElementById('recycle-bin-list');
  if (!list) return;
  const typeLabels = {
    note: 'Flashnote', task: 'Task', subject: 'Course', schedule: 'Timetable class',
    attendance: 'Attendance record', grade: 'Grade component', session: 'Study session',
  };
  list.innerHTML = recycleBinItems.map(item => {
    const expiresAt = new Date(`${item.expiresAt.replace(' ', 'T')}Z`);
    const daysLeft = Math.max(0, Math.ceil((expiresAt.getTime() - Date.now()) / 86400000));
    const deletedAt = new Date(`${item.deletedAt.replace(' ', 'T')}Z`).toLocaleString();
    return `
      <article class="card recycle-item">
        <div class="recycle-item-info">
          <span>${escapeHtml(typeLabels[item.type] || 'Item')}</span>
          <h4>${escapeHtml(item.label)}</h4>
          <small>Deleted ${escapeHtml(deletedAt)} · ${daysLeft} day${daysLeft === 1 ? '' : 's'} left</small>
        </div>
        <div class="recycle-item-actions">
          <button type="button" class="pill-btn" onclick="restoreRecycleItem(${item.id})">Restore</button>
          <button type="button" class="icon-btn" title="Delete permanently" aria-label="Delete ${escapeHtml(item.label)} permanently" onclick="permanentlyDeleteRecycleItem(${item.id})">🗑️</button>
        </div>
      </article>
    `;
  }).join('') || '<div class="card recycle-empty">Recycle Bin is empty.</div>';
}

async function refreshRecycleBin() {
  try {
    const result = await api('/recycle-bin');
    recycleBinItems = result.data || [];
    renderRecycleBin();
  } catch (error) {
    showToast(error.message, true);
  }
}

async function restoreRecycleItem(id) {
  try {
    await api(`/recycle-bin/${id}/restore`, 'POST');
    showToast('Item restored.');
    await refreshAllData();
  } catch (error) {
    showToast(error.message, true);
  }
}

async function undoRecycleBinEntry(id) {
  try {
    await api(`/recycle-bin/${id}/restore`, 'POST');
    await refreshAllData();
    showToast('Item restored.');
  } catch (error) {
    showToast(error.message, true);
  }
}

async function permanentlyDeleteRecycleItem(id) {
  const item = recycleBinItems.find(entry => entry.id === id);
  if (!item || !confirm(`Permanently delete "${item.label}"? This cannot be undone.`)) return;
  try {
    await api(`/recycle-bin/${id}`, 'DELETE');
    showToast('Item permanently deleted.');
    await refreshAllData();
  } catch (error) {
    showToast(error.message, true);
  }
}

// ============================================================================
// Modals & Forms
// ============================================================================
function populateSelects() {
  const taskSub = document.getElementById('task-input-subject');
  const noteSub = document.getElementById('note-input-subject');
  const timerSub = document.getElementById('timer-subject-select');
  const slotSub = document.getElementById('slot-input-subject');

  const options = `<option value="">General (No Course)</option>` +
    subjects.map(s => `<option value="${s.id}">${s.code} · ${s.title}</option>`).join('');

  if (taskSub) taskSub.innerHTML = options;
  if (noteSub) noteSub.innerHTML = options;
  if (timerSub) timerSub.innerHTML = options;
  if (slotSub) {
    slotSub.innerHTML = '<option value="">Select a course</option>' +
      subjects.map(subject => `<option value="${subject.id}">${subject.code} · ${subject.title}</option>`).join('');
  }
}

function openNewSlotModal() {
  populateSelects();
  document.getElementById('slot-form').reset();
  document.getElementById('slot-input-day').value = String(currentScheduleDate.getDay());
  document.getElementById('slot-modal').classList.add('open');
  document.getElementById('slot-input-subject').focus();
}

async function handleCreateSlot(e) {
  e.preventDefault();
  const subjectId = Number(document.getElementById('slot-input-subject').value);
  const dayOfWeek = Number(document.getElementById('slot-input-day').value);
  const startTime = document.getElementById('slot-input-start').value;
  const endTime = document.getElementById('slot-input-end').value;
  const room = document.getElementById('slot-input-room').value.trim();
  const modality = document.getElementById('slot-input-modality').value;

  if (endTime <= startTime) {
    showToast('End time must be later than start time.', true);
    return;
  }

  try {
    await api('/schedule', 'POST', {
      subjectId,
      dayOfWeek,
      startTime,
      endTime,
      room: room || null,
      modality: modality || null,
    });
    closeModal('slot-modal');
    showToast('Class added to your timetable.');
    await refreshAllData();
  } catch (err) {
    showToast(err.message, true);
  }
}

function openNewTaskModal() {
  populateSelects();
  document.getElementById('task-form').reset();
  document.getElementById('task-modal').classList.add('open');
}

function openNewCourseModal() {
  document.getElementById('course-form').reset();
  document.getElementById('course-modal').classList.add('open');
  document.getElementById('course-input-code').focus();
}

async function handleCreateCourse(e) {
  e.preventDefault();
  const code = document.getElementById('course-input-code').value.trim();
  const title = document.getElementById('course-input-title').value.trim();
  const instructor = document.getElementById('course-input-instructor').value.trim();
  const instructorEmail = document.getElementById('course-input-email').value.trim();
  const units = Number(document.getElementById('course-input-units').value);
  const color = document.getElementById('course-input-color').value;

  try {
    await api('/subjects', 'POST', {
      code,
      title,
      instructor: instructor || null,
      instructorEmail: instructorEmail || null,
      units,
      color,
    });
    closeModal('course-modal');
    showToast('Course added successfully!');
    await refreshAllData();
  } catch (err) {
    showToast(err.message, true);
  }
}

function openNewNoteModal(subjectId = null) {
  populateSelects();
  editingNoteId = null;
  document.getElementById('note-form').reset();
  document.getElementById('note-modal-title').textContent = 'New Study Flashnote';
  document.getElementById('note-submit-button').textContent = 'Save Flashnote';
  if (subjectId) document.getElementById('note-input-subject').value = subjectId;
  document.getElementById('note-modal').classList.add('open');
}

function closeModal(id) {
  if (id === 'attachment-preview-modal' && activeAttachmentPreviewUrl) {
    URL.revokeObjectURL(activeAttachmentPreviewUrl);
    activeAttachmentPreviewUrl = null;
  }
  if (id === 'note-reader-modal') {
    activeReviewMode = false;
    reviewQueue = [];
  }
  document.getElementById(id).classList.remove('open');
}

function formatAttachmentSize(size) {
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(0)} KB`;
  return `${(size / (1024 * 1024)).toFixed(1)} MB`;
}

function renderAttachmentControls(files) {
  if (!files.length) return '';
  return `<div class="attachment-file-list">${files.map(file => {
    const extension = (file.originalName.split('.').pop() || 'FILE').toUpperCase().slice(0, 5);
    return `
      <div class="attachment-file-row">
        <button type="button" class="attachment-download" onclick="previewAttachment(${file.id})" aria-label="Preview ${escapeHtml(file.originalName)}">
          <span class="attachment-file-type">${escapeHtml(extension)}</span>
          <span class="attachment-file-name">${escapeHtml(file.originalName)}<small>${formatAttachmentSize(file.sizeBytes)}</small></span>
          <span class="attachment-preview-mark" aria-hidden="true">View</span>
        </button>
        <button type="button" class="icon-btn attachment-download-button" onclick="downloadAttachment(${file.id})" aria-label="Download ${escapeHtml(file.originalName)}" title="Download file">↓</button>
        <button type="button" class="icon-btn attachment-remove" onclick="deleteAttachment(${file.id})" aria-label="Remove ${escapeHtml(file.originalName)}" title="Remove attachment">×</button>
      </div>`;
  }).join('')}</div>`;
}

async function uploadAttachments(resourceType, resourceId, files) {
  const selectedFiles = Array.from(files || []);
  if (!selectedFiles.length) return { uploaded: 0, errors: [] };

  const existingFiles = (resourceType === 'works' ? workAttachments : noteAttachments)
    .filter(file => file.resourceId === Number(resourceId)).length;
  if (existingFiles + selectedFiles.length > 10) {
    return { uploaded: 0, errors: ['Each task or note can have up to 10 files.'] };
  }

  let uploaded = 0;
  const errors = [];
  for (const file of selectedFiles) {
    if (file.size > 20 * 1024 * 1024) {
      errors.push(`${file.name} is larger than 20 MB.`);
      continue;
    }

    const formData = new FormData();
    formData.append('file', file);
    try {
      const response = await fetch(`/api/attachments/${resourceType}/${resourceId}`, {
        method: 'POST',
        headers: authToken ? { Authorization: `Bearer ${authToken}` } : {},
        body: formData,
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(result.error?.message || 'Upload failed');
      uploaded += 1;
    } catch (error) {
      errors.push(`${file.name}: ${error.message}`);
    }
  }
  return { uploaded, errors };
}

async function chooseAttachments(resourceType, resourceId) {
  if (!resourceId) return;
  const picker = document.createElement('input');
  picker.type = 'file';
  picker.multiple = true;
  picker.accept = '.png,.jpg,.jpeg,.gif,.webp,.pdf,.doc,.docx,.ppt,.pptx,.txt';
  picker.onchange = async () => {
    if (!picker.files?.length) return;
    const result = await uploadAttachments(resourceType, resourceId, picker.files);
    await refreshAllData();
    showToast(result.errors.length ? result.errors[0] : `${result.uploaded} file${result.uploaded === 1 ? '' : 's'} attached.` , result.errors.length > 0);
    if (activeNoteId === Number(resourceId)) openNoteDetails(activeNoteId);
  };
  picker.click();
}

function chooseTaskAttachments(id) {
  chooseAttachments('works', id);
}

function chooseNoteAttachments(id) {
  chooseAttachments('notes', id);
}

async function fetchAttachmentBlob(id) {
  const attachment = [...workAttachments, ...noteAttachments].find(file => file.id === Number(id));
  if (!attachment) throw new Error('This attachment is no longer available.');
  const response = await fetch(`/api/attachments/${id}/download`, {
    headers: authToken ? { Authorization: `Bearer ${authToken}` } : {},
  });
  if (!response.ok) {
    const result = await response.json().catch(() => ({}));
    throw new Error(result.error?.message || 'Could not load this file.');
  }
  return { attachment, blob: await response.blob() };
}

async function previewAttachment(id) {
  const title = document.getElementById('attachment-preview-title');
  const content = document.getElementById('attachment-preview-content');
  const downloadButton = document.getElementById('attachment-preview-download');
  content.replaceChildren();
  title.textContent = 'Loading preview...';
  document.getElementById('attachment-preview-modal').classList.add('open');

  try {
    const { attachment, blob } = await fetchAttachmentBlob(id);
    title.textContent = attachment.originalName;
    downloadButton.onclick = () => downloadAttachment(id);

    if (attachment.mimeType.startsWith('image/')) {
      activeAttachmentPreviewUrl = URL.createObjectURL(blob);
      const image = document.createElement('img');
      image.className = 'attachment-preview-image';
      image.src = activeAttachmentPreviewUrl;
      image.alt = attachment.originalName;
      content.append(image);
    } else if (attachment.mimeType === 'application/pdf') {
      activeAttachmentPreviewUrl = URL.createObjectURL(blob);
      const frame = document.createElement('iframe');
      frame.className = 'attachment-preview-pdf';
      frame.src = activeAttachmentPreviewUrl;
      frame.title = `Preview of ${attachment.originalName}`;
      content.append(frame);
    } else if (attachment.mimeType === 'text/plain') {
      const text = document.createElement('pre');
      text.className = 'attachment-preview-text';
      text.textContent = await blob.text();
      content.append(text);
    } else {
      const message = document.createElement('p');
      message.className = 'attachment-preview-message';
      message.textContent = 'This file type cannot be displayed in the browser. You can download it to open it in a compatible app.';
      content.append(message);
    }
  } catch (error) {
    title.textContent = 'Preview unavailable';
    const message = document.createElement('p');
    message.className = 'attachment-preview-message';
    message.textContent = error.message;
    content.append(message);
    showToast(error.message, true);
  }
}

async function downloadAttachment(id) {
  try {
    const { attachment, blob } = await fetchAttachmentBlob(id);
    const objectUrl = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = objectUrl;
    link.download = attachment.originalName;
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
  } catch (error) {
    showToast(error.message, true);
  }
}

async function deleteAttachment(id) {
  const attachment = [...workAttachments, ...noteAttachments].find(file => file.id === Number(id));
  if (!attachment || !confirm(`Remove "${attachment.originalName}"?`)) return;
  try {
    await api(`/attachments/${id}`, 'DELETE');
    await refreshAllData();
    if (activeNoteId === attachment.resourceId && attachment.resourceType === 'note') openNoteDetails(activeNoteId);
    showToast('Attachment removed.');
  } catch (error) {
    showToast(error.message, true);
  }
}

async function handleCreateTask(e) {
  e.preventDefault();
  const title = document.getElementById('task-input-title').value.trim();
  const subjectId = document.getElementById('task-input-subject').value || null;
  const type = document.getElementById('task-input-type').value;
  const priority = document.getElementById('task-input-priority').value;
  const dueAt = document.getElementById('task-input-due').value || null;
  const files = document.getElementById('task-attachment-files').files;

  try {
    const response = await api('/works', 'POST', {
      title,
      subjectId: subjectId ? Number(subjectId) : null,
      type,
      priority,
      dueAt: dueAt ? new Date(dueAt).toISOString() : null,
    });
    const uploadResult = await uploadAttachments('works', response.data.id, files);
    closeModal('task-modal');
    document.getElementById('task-form').reset();
    await refreshAllData();
    showToast(uploadResult.errors.length ? `Task saved. ${uploadResult.errors[0]}` : 'Assignment created successfully! ✨');
  } catch (err) {
    showToast(err.message, true);
  }
}

async function handleCreateNote(e) {
  e.preventDefault();
  const title = document.getElementById('note-input-title').value.trim();
  const subjectId = document.getElementById('note-input-subject').value || null;
  const content = document.getElementById('note-input-content').value.trim();
  const tags = document.getElementById('note-input-tags').value.trim();
  const currentNote = notesList.find(note => note.id === editingNoteId);
  const payload = {
    title,
    subjectId: subjectId ? Number(subjectId) : null,
    content,
    tags,
    isPinned: currentNote?.isPinned ?? true,
  };

  try {
    const isEditing = editingNoteId !== null;
    const selectedFiles = document.getElementById('note-attachment-files').files;
    const response = await api(isEditing ? `/notes/${editingNoteId}` : '/notes', isEditing ? 'PUT' : 'POST', payload);
    const noteId = isEditing ? editingNoteId : response.data.id;
    const uploadResult = await uploadAttachments('notes', noteId, selectedFiles);
    closeModal('note-modal');
    document.getElementById('note-form').reset();
    editingNoteId = null;
    await refreshAllData();
    showToast(uploadResult.errors.length ? `Flashnote saved. ${uploadResult.errors[0]}` : isEditing ? 'Flashnote updated.' : 'Flashnote saved! 📝');
  } catch (err) {
    showToast(err.message, true);
  }
}

// ============================================================================
// Confetti Animation Engine
// ============================================================================
function triggerConfetti() {
  const canvas = document.getElementById('confetti-canvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;

  const particles = Array.from({ length: 65 }).map(() => ({
    x: canvas.width / 2,
    y: canvas.height / 2,
    vx: (Math.random() - 0.5) * 14,
    vy: (Math.random() - 0.8) * 16,
    color: ['#A51C30', '#10B981', '#F59E0B', '#EC4899', '#06B6D4'][Math.floor(Math.random() * 5)],
    size: Math.random() * 8 + 4,
    rotation: Math.random() * 360,
    vr: (Math.random() - 0.5) * 10,
    life: 1,
  }));

  function loop() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    let active = false;
    for (const p of particles) {
      if (p.life <= 0) continue;
      active = true;
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.4; // gravity
      p.rotation += p.vr;
      p.life -= 0.015;

      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate((p.rotation * Math.PI) / 180);
      ctx.fillStyle = p.color;
      ctx.globalAlpha = Math.max(0, p.life);
      ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size);
      ctx.restore();
    }
    if (active) requestAnimationFrame(loop);
  }
  loop();
}

// ============================================================================
// Utilities & Navigation
// ============================================================================
function switchView(viewId) {
  toggleMobileMenu(false);
  document.querySelectorAll('.view-section').forEach(s => s.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  document.querySelectorAll('.b-nav-item').forEach(n => {
    n.classList.toggle('active', n.dataset.view === viewId);
    if (n.dataset.view === viewId) n.setAttribute('aria-current', 'page');
    else n.removeAttribute('aria-current');
  });
  document.querySelectorAll('.mobile-menu-item').forEach(item => {
    item.classList.toggle('active', item.dataset.view === viewId);
    if (item.dataset.view === viewId) item.setAttribute('aria-current', 'page');
    else item.removeAttribute('aria-current');
  });
  const primaryViews = ['dashboard', 'schedule', 'works', 'focus', 'notes'];
  document.getElementById('btn-mobile-more')?.classList.toggle('active', !primaryViews.includes(viewId));

  const viewEl = document.getElementById(`view-${viewId}`);
  if (viewEl) viewEl.classList.add('active');

  const navItem = document.querySelector(`[data-view="${viewId}"]`);
  if (navItem) navItem.classList.add('active');

  const titles = {
    dashboard: "Today's Overview",
    schedule: "Academic Timetable",
    attendance: "Attendance & Cut Calculator",
    works: "Tasks & School Works",
    focus: "Study Focus Zone (Pomodoro)",
    grades: "Courses & GPA Solver",
    notes: "Study Flashnotes & Cheat Sheets",
    'recycle-bin': 'Recycle Bin',
  };
  document.getElementById('page-title').textContent = titles[viewId] || 'ClassMate';
  if (viewId === 'recycle-bin') renderRecycleBin();
}

function toggleMobileMenu(forceOpen) {
  const menu = document.getElementById('mobile-more-menu');
  const button = document.getElementById('btn-mobile-more');
  if (!menu || !button) return;
  const shouldOpen = typeof forceOpen === 'boolean' ? forceOpen : menu.hidden;
  menu.hidden = !shouldOpen;
  button.setAttribute('aria-expanded', String(shouldOpen));
}

function initTheme() {
  const toggles = [...document.querySelectorAll('#theme-toggle, #auth-theme-toggle')];
  const applyTheme = (theme) => {
    const activeTheme = theme === 'light' ? 'light' : 'dark';
    const nextTheme = activeTheme === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', activeTheme);
    localStorage.setItem('classmate_theme', activeTheme);

    for (const toggle of toggles) {
      const label = `Switch to ${nextTheme} theme`;
      toggle.setAttribute('aria-label', label);
      toggle.title = label;
      const icon = toggle.querySelector('svg');
      if (icon) {
        icon.innerHTML = activeTheme === 'dark'
          ? '<circle cx="12" cy="12" r="4"></circle><path d="M12 2v2m0 16v2m10-10h-2M4 12H2m17.07 7.07-1.42-1.42M6.35 6.35 4.93 4.93m14.14 0-1.42 1.42M6.35 17.65l-1.42 1.42"></path>'
          : '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>';
      }
    }

    const themeColor = document.querySelector('meta[name="theme-color"]');
    if (themeColor) themeColor.content = activeTheme === 'dark' ? '#0c1215' : '#eef4f1';
  };

  const saved = localStorage.getItem('classmate_theme');
  applyTheme(saved === 'light' ? 'light' : 'dark');

  for (const toggle of toggles) {
    toggle.onclick = () => {
      const current = document.documentElement.getAttribute('data-theme');
      applyTheme(current === 'dark' ? 'light' : 'dark');
    };
  }
}

function formatClock(hhmm) {
  if (!hhmm) return '';
  const [h, m] = hhmm.split(':').map(Number);
  const ampm = h >= 12 ? 'PM' : 'AM';
  const h12 = h % 12 || 12;
  return `${h12}:${String(m).padStart(2, '0')} ${ampm}`;
}

function formatDue(isoStr) {
  if (!isoStr) return '';
  const due = new Date(isoStr);
  const now = new Date();
  const diffDays = Math.ceil((due - now) / (1000 * 60 * 60 * 24));
  if (diffDays < 0) return `Overdue by ${Math.abs(diffDays)}d`;
  if (diffDays === 0) return 'Due today';
  if (diffDays === 1) return 'Due tomorrow';
  return `Due in ${diffDays}d`;
}

function reminderStorageKey() {
  const identity = currentUser?.id ?? currentUser?.email ?? 'student';
  return `classmate_deadline_reminders_${encodeURIComponent(identity)}`;
}

function sentRemindersStorageKey() {
  const identity = currentUser?.id ?? currentUser?.email ?? 'student';
  return `classmate_sent_deadline_reminders_${encodeURIComponent(identity)}`;
}

function updateReminderButton() {
  const button = document.getElementById('btn-reminders');
  if (!button) return;
  const supported = 'Notification' in window && window.isSecureContext;
  const enabled = supported &&
    localStorage.getItem(reminderStorageKey()) === 'enabled' &&
    Notification.permission === 'granted';
  button.classList.toggle('active', enabled);
  button.setAttribute('aria-pressed', String(enabled));
  button.setAttribute('aria-label', enabled ? 'Disable deadline reminders' : 'Enable deadline reminders');
  const label = button.querySelector('span:last-child');
  if (label) label.textContent = enabled ? 'Reminders on' : 'Reminders';
  button.title = supported
    ? (enabled ? 'Turn off deadline reminders' : 'Get a browser notification for tasks due within 24 hours')
    : 'Browser notifications are unavailable in this browser or connection';
}

async function enableDeadlineReminders() {
  if (localStorage.getItem(reminderStorageKey()) === 'enabled') {
    localStorage.removeItem(reminderStorageKey());
    updateReminderButton();
    showToast('Deadline reminders turned off.');
    return;
  }
  if (!('Notification' in window) || !window.isSecureContext) {
    showToast('Notifications need a supported browser and a secure (HTTPS) connection.', true);
    return;
  }
  const isAppleMobile = /iPhone|iPad|iPod/i.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const isInstalled = navigator.standalone || window.matchMedia('(display-mode: standalone)').matches;
  if (isAppleMobile && !isInstalled) {
    showToast('On iPhone or iPad, add ClassMate to your Home Screen and open it before enabling notifications.', true);
    return;
  }

  try {
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      showToast('Notification permission was not granted. You can change it in browser settings.', true);
      return;
    }
    localStorage.setItem(reminderStorageKey(), 'enabled');
    updateReminderButton();
    checkDeadlineReminders();
    showToast('Deadline reminders enabled for tasks due in the next 24 hours.');
  } catch (error) {
    console.error('Could not enable deadline reminders:', error);
    showToast('Could not enable notifications. Check your browser settings and try again.', true);
  }
}

function showBrowserNotification(title, body, tag) {
  if (!('Notification' in window) || Notification.permission !== 'granted') return;
  const options = {
    body,
    tag,
    data: { view: tag === 'classmate-focus-timer' ? 'focus' : 'works' },
  };
  const showWithRegistration = registration => {
    if (!registration?.showNotification) throw new Error('Service worker notifications are unavailable.');
    return registration.showNotification(title, options);
  };
  const reportFailure = error => {
    console.error('Could not display browser notification:', error);
    showToast('A reminder could not be displayed. Check your browser notification settings.', true);
  };

  if (serviceWorkerRegistration) {
    showWithRegistration(serviceWorkerRegistration).catch(reportFailure);
    return;
  }

  if ('serviceWorker' in navigator && window.isSecureContext) {
    navigator.serviceWorker.ready
      .then(registration => {
        serviceWorkerRegistration = registration;
        return showWithRegistration(registration);
      })
      .catch(error => {
        if (/iPhone|iPad|iPod/i.test(navigator.userAgent) ||
            (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)) {
          reportFailure(error);
          return;
        }
        try {
          const notification = new Notification(title, options);
          notification.onclick = () => {
            window.focus();
            switchView(options.data.view);
            notification.close();
          };
        } catch (fallbackError) {
          reportFailure(fallbackError);
        }
      });
    return;
  }

  try {
    const notification = new Notification(title, options);
    notification.onclick = () => {
      window.focus();
      switchView(options.data.view);
      notification.close();
    };
  } catch (error) {
    reportFailure(error);
  }
}

function registerServiceWorker() {
  if (!('serviceWorker' in navigator) || !window.isSecureContext) return;
  navigator.serviceWorker.getRegistrations()
    .then(async registrations => {
      const legacyRegistrations = registrations.filter(registration =>
        [registration.active, registration.waiting, registration.installing]
          .filter(Boolean)
          .some(worker => new URL(worker.scriptURL).pathname.endsWith('/flutter_service_worker.js')),
      );
      await Promise.all(legacyRegistrations.map(registration => registration.unregister()));
      if ('caches' in window) {
        const flutterCaches = (await caches.keys()).filter(name => name.startsWith('flutter-'));
        await Promise.all(flutterCaches.map(name => caches.delete(name)));
      }
    })
    .then(() => navigator.serviceWorker.register('/service-worker.js'))
    .then(registration => {
      serviceWorkerRegistration = registration;
    })
    .catch(error => {
      console.error('Could not register the notification service worker:', error);
    });
}

function checkDeadlineReminders() {
  if (!currentUser || !('Notification' in window) ||
      Notification.permission !== 'granted' ||
      localStorage.getItem(reminderStorageKey()) !== 'enabled') return;

  const sent = JSON.parse(localStorage.getItem(sentRemindersStorageKey()) || '[]');
  const now = Date.now();
  let changed = false;
  schoolWorks.forEach(work => {
    if (work.status === 'done' || !work.dueAt) return;
    const dueAt = new Date(work.dueAt).getTime();
    const key = `${work.id}:${work.dueAt}`;
    if (dueAt <= now || dueAt - now > 24 * 60 * 60 * 1000 || sent.includes(key)) return;
    showBrowserNotification(
      `Coming up: ${work.title}`,
      `${work.subjectCode || 'General'} · ${formatDue(work.dueAt)}`,
      `classmate-deadline-${work.id}`,
    );
    sent.push(key);
    changed = true;
  });
  if (changed) localStorage.setItem(sentRemindersStorageKey(), JSON.stringify(sent));
}

function showToast(msg, isError = false, action = null) {
  const toast = document.createElement('div');
  toast.className = 'app-toast';
  toast.style.cssText = `
    position: fixed; bottom: 24px; right: 24px; z-index: 9999;
    display: flex; align-items: center; gap: 14px; max-width: min(460px, calc(100vw - 32px));
    padding: 12px 16px; border-radius: 12px; font-size: 13.5px; font-weight: 700;
    color: #fff; background: ${isError ? 'var(--rose)' : 'var(--primary)'};
    box-shadow: 0 8px 24px rgba(0,0,0,0.3); animation: fadeIn 0.25s ease;
  `;
  const message = document.createElement('span');
  message.textContent = msg;
  toast.appendChild(message);
  if (action) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'toast-action';
    button.textContent = action.label;
    button.onclick = () => {
      toast.remove();
      action.onClick();
    };
    toast.appendChild(button);
  }
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 3200);
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, character => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]);
}

// Global Nav Clicks
document.querySelectorAll('.nav-item').forEach(item => {
  item.onclick = () => switchView(item.dataset.view);
});

document.querySelectorAll('.b-nav-item').forEach(item => {
  if (item.dataset.view) item.onclick = () => switchView(item.dataset.view);
});

document.querySelectorAll('.mobile-menu-item').forEach(item => {
  item.onclick = () => switchView(item.dataset.view);
});

document.getElementById('btn-logout').onclick = logout;

document.addEventListener('visibilitychange', () => {
  if (!document.hidden) {
    tickFocusTimer();
    checkDeadlineReminders();
  }
});

document.addEventListener('keydown', event => {
  if (event.key === 'Escape') toggleMobileMenu(false);
});

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.addEventListener('message', event => {
    if (event.data?.type === 'classmate-open-view' && typeof event.data.view === 'string') {
      switchView(event.data.view);
    }
  });
}

// Start!
init();
setInterval(checkDeadlineReminders, 60 * 1000);
