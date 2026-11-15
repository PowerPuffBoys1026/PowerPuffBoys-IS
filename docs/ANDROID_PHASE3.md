# ClassMate v2 — Phase 3: UI Parity

**Status:** implemented; `flutter analyze` 0 errors/warnings, 21/21 tests pass.
**Branch:** `feature/android-v2`
**Scope:** Flutter client UI only. No device run yet (Phase 4).

---

## 1. Goal

Expose every Phase 2 API from the app so the Android build reaches feature parity
with the v2 web experience, without introducing a new design language (all screens
reuse the existing Midnight Glass theme/cards).

## 2. Navigation

`HomeShell` now has six destinations:

| # | Tab | Screen |
|---|---|---|
| 0 | Home | `DashboardScreen` (unchanged) |
| 1 | Schedule | `ScheduleScreen` (extended) |
| 2 | Works | `WorksScreen` (extended) |
| 3 | Grades | `GradesScreen` (new) |
| 4 | Focus | `FocusScreen` (new) |
| 5 | More | `MoreScreen` (new hub) |

"More" hosts **Attendance**, **Subjects**, **Notes**, **Recycle bin**,
**Profile**, and **Settings** as pushed routes, plus the sign-out action.
Existing Attendance/Subjects/Notes screens are reused unchanged apart from the
subject form.

## 3. New screens

| File | What it does |
|---|---|
| `lib/screens/grades_screen.dart` | Cumulative GPA/standing card, per-subject progress + letter/GPA, remaining-weight "need X% to hit target" hint, component CRUD (long-press or menu), target/weight/score validation |
| `lib/screens/focus_screen.dart` | Focus / short-break / long-break modes, circular countdown, 15/25/45/60 presets, subject link, start/pause/reset, auto-log on completion, manual log, today/week/streak stats, per-subject minutes, recent sessions with delete |
| `lib/screens/more_screen.dart` | Hub tiles + signed-in header, pushes the remaining screens inside the glass background |
| `lib/screens/profile_screen.dart` | Edit full name/student no/course/year level (`PUT /auth/me`), change password with confirm + min-8 validation (`PUT /auth/me/password`) |
| `lib/screens/settings_screen.dart` | View/edit the runtime API URL, save + refresh, reset to build default, "Test" connection via `GET /auth/me` |
| `lib/screens/recycle_bin_screen.dart` | List deleted items with type/deleted/expiry, restore, delete forever, refresh |
| `lib/widgets/attachments_panel.dart` | Shared attachment list: pick + upload (`file_picker`), download to temp + open (`open_filex`), delete; used in a dialog for works and notes |

## 4. Extended existing screens

| File | Change |
|---|---|
| `home_shell.dart` | Six tabs (Home/Schedule/Works/Grades/Focus/More); rail + bottom bar |
| `subjects_screen.dart` | Instructor email + office hours fields/display |
| `schedule_screen.dart` | Building + week pattern (A/B/every) fields; tap a class card to edit (`PUT /schedule/:id`); building/week chip shown on the card |
| `works_screen.dart` | Edit dialog (title/subject/type/priority/due/notes → full PUT); "Attachments" menu action |
| `note_editor_screen.dart` | "Linked subject" picker (saved via `subjectId`), attachments action |
| `utils/format.dart` | `formatBytes`, `formatDuration` helpers |

## 5. Packages added

| Package | Version | Why |
|---|---|---|
| `flutter_secure_storage` | 11.2.0 | Phase 2 token storage (already added) |
| `file_picker` | 13.3.3 | Native file selection for attachments |
| `open_filex` | 5.0.0 | Open downloaded attachment via Android intent |
| `path_provider` | 2.1.6 | Temp directory for downloads (promoted to direct dep) |

Android notes:

- `file_picker` uses SAF; no storage permissions required.
- `open_filex` ships its FileProvider entry; no manifest edits needed.
- Both plugin registrants are generated; commit them with the plugin changes.

## 6. Data behaviour

- On sign-in `_Root` loads `AppState`, `NotesState`, `GradesState`, `StudyState`;
  on sign-out all four are reset.
- Grades/study mutations re-fetch list + summary/stats so dashboard cards stay
  coherent with the server (single source of truth).
- Attachment upload uses `readAsBytes()` + multipart bytes so Android
  `content://` picks work without a filesystem path.
- Server URL changes take effect immediately (`ApiClient.baseUrl`), no rebuild.

## 7. Verification

```
cd client
flutter analyze   # 0 errors, 0 warnings, 9 info (use_null_aware_elements, style)
flutter test      # 21/21 pass
```

Not verified yet:

- visual layout on a real 360–430 dp phone (Phase 4)
- file picker/download/open flow on Android
- timer accuracy across screen-off/background (uses wall-clock-independent
  `Timer.periodic`; acceptable for a study timer, revisit if Android throttles)
- server URL change followed by login against a second host

## 8. Known limitations

- `AttachmentsPanel` imports `dart:io` (temp files, `open_filex`), so
  `flutter build web` is no longer supported from this branch. Android/desktop
  builds are unaffected. Revisit with conditional imports if web parity is needed.
- Focus timer does not persist across app restarts; a session is logged only when
  the timer completes or the user taps log.
- Subject/slot edits send explicit empty strings for optional text (server treats
  them via its own trimming rules), and clearing a slot's room is not exposed in
  the edit form (create/update still accepts null from the API layer).
- Six-tab bottom bar is tight on very narrow screens; acceptable for the project
  phones (>=360 dp).

## 9. Next phase (Phase 4)

1. Commit + push the branch; let GitHub Actions produce the first APK.
2. Install on a phone, start PostgreSQL + `npm start` on the laptop.
3. QA script: login, server URL switch, subject/slot extended fields, grade CRUD
   + GPA math, focus session log/stats, attachments upload/open/delete, recycle
   restore/purge, profile + password change, logout/login.
4. Generate a release keystore + repo secrets, rebuild signed APK.
5. Tag `v2.0.0` after QA sign-off; merge both v2 PRs before `main` (BL-002).
