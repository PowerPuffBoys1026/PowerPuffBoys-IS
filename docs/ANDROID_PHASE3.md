# ClassMate v2 — Phase 3: UI Parity & Field-Journal Refresh

**Status:** implemented; `flutter analyze` clean, 24/24 tests pass, CI APK built
from `55b9932` (run `43860338196`).
**Branch:** `feature/android-v2`
**Scope:** Flutter client UI only. No device run yet (Phase 4).

---

## 1. Goal

Expose every Phase 2 API from the app and replace the original Midnight Glass
shell with the v2 field-journal design from `Version 2 UI UX/public`. The Phase 2
data/API layer is unchanged; screens now use the v2 palette, cards, pills,
editorial typography, light/dark themes, and the v2 navigation model.

## 2. Navigation

`HomeShell` now has eight in-shell destinations:

| # | Destination | Screen |
|---|---|---|
| 0 | Today | `DashboardScreen` |
| 1 | Timetable | `ScheduleScreen` |
| 2 | Attendance | `AttendanceScreen` |
| 3 | Tasks | `WorksScreen` |
| 4 | Focus Zone | `FocusScreen` |
| 5 | Courses & GPA | `GradesScreen` |
| 6 | Flashnotes | `NotesScreen` |
| 7 | Recycle Bin | `RecycleBinScreen` |

Wide screens use a `NavigationRail` with all eight destinations. The phone bottom
bar shows **Today · Plan · Tasks · Focus · Notes · More**; the More sheet opens
Attendance, Courses & GPA, Recycle Bin, Profile, Settings, the theme toggle, and
sign out. Profile and Settings are pushed routes.

The six-tab `MoreScreen` hub from the first parity pass remains in the tree but is
no longer imported by the shell.

## 3. Screens and UI foundation

| File | What it does |
|---|---|
| `lib/theme.dart` | v2 `AppColors` extension + light/dark `buildTheme` |
| `lib/state/theme_state.dart` | persisted light/dark mode (`theme_mode`) |
| `lib/widgets/v2_kit.dart` | shared v2 kit: glass cards, pills, buttons, section headings, sheet headers |
| `lib/screens/auth_layout.dart` | editorial auth shell with hero image/gradient fallback and form panel |
| `lib/screens/login_screen.dart` | v2 login form on `AuthLayout` |
| `lib/screens/register_screen.dart` | v2 registration form on `AuthLayout` |
| `lib/screens/home_shell.dart` | v2 rail/bottom nav, More sheet, theme toggle, eight-view `IndexedStack` |
| `lib/screens/dashboard_screen.dart` | v2 overview with today's classes, deadlines, attendance and GPA cards |
| `lib/screens/attendance_screen.dart` | health banner, safe-cut stats, per-course cards, quick Present/Late/Absent marking, custom-date dialog |
| `lib/screens/schedule_screen.dart` | week-at-a-glance plan, week/day toggle, clipboard export, class detail sheet with edit/delete/mark-present, slot form |
| `lib/screens/works_screen.dart` | searchable task cards, status filters, checkbox completion, status menu, attachments/edit/delete |
| `lib/screens/focus_screen.dart` | stat tiles, timer ring, mode/preset pills, subject selector, focus log/history |
| `lib/screens/grades_screen.dart` | GPA hero, per-subject cards, component rows, target solver slider, subject-management link |
| `lib/screens/notes_screen.dart` | searchable flashnote card grid with pin/edit/delete |
| `lib/screens/note_reader_screen.dart` | full-note reader with pin/edit/delete and tags |
| `lib/screens/note_editor_screen.dart` | theme-aware formatting toolbar, subject link, save flow |
| `lib/screens/recycle_bin_screen.dart` | shell-compatible v2 recycle bin with restore/purge and empty/error states |
| `lib/screens/profile_screen.dart` | v2 profile form and password change |
| `lib/screens/settings_screen.dart` | v2 server URL editor and connection test |
| `lib/screens/subjects_screen.dart` | v2 subject cards/forms with instructor email and office hours |

## 4. Extended existing screens

| File | Change |
|---|---|
| `home_shell.dart` | eight in-shell views, rail + phone bottom bar, More sheet, theme toggle |
| `schedule_screen.dart` | building + week pattern fields, weekly grid, export, tap-to-edit |
| `works_screen.dart` | search/status filters, card completion toggle, full edit, attachments |
| `grades_screen.dart` | links to Subjects for adding/managing courses |
| `note_editor_screen.dart` | linked-subject picker and attachments action |
| `utils/format.dart` | `formatDate`, `formatBytes`, `formatDuration` helpers |
| `more_screen.dart` | legacy hub retained but unused by the shell |

## 5. Packages added

| Package | Version | Why |
|---|---|---|
| `flutter_secure_storage` | 11.2.0 | Phase 2 token storage |
| `file_picker` | 13.3.3 | Native file selection for attachments |
| `open_filex` | 5.0.0 | Open downloaded attachment via Android intent |
| `path_provider` | 2.1.6 | Temp directory for downloads |

Android notes:

- `file_picker` uses SAF; no storage permissions required.
- `open_filex` ships its FileProvider entry; no manifest edits needed.
- Both plugin registrants are generated; commit them with the plugin changes.
- Ambient focus audio is deferred; no `audioplayers` dependency was added yet.

## 6. Data behaviour

- On sign-in `_Root` loads `AppState`, `NotesState`, `GradesState`, `StudyState`;
  on sign-out all four are reset.
- The light/dark choice persists through `SharedPreferences` key `theme_mode`.
- Grades/study mutations re-fetch list + summary/stats so dashboard cards stay
  coherent with the server (single source of truth).
- The grades target slider updates each component through
  `grades.update(id, targetPct: target)` and re-fetches the summary.
- Attachment upload uses `readAsBytes()` + multipart bytes so Android
  `content://` picks work without a filesystem path.
- Server URL changes take effect immediately (`ApiClient.baseUrl`), no rebuild.

## 7. Verification

```
cd client
flutter analyze   # No issues found
flutter test      # 24/24 pass
```

CI: run `43860338196` — **Success** from commit `55b9932`; artifact
`classmate-v2-apk` (`app-release.apk`, debug-signed until keystore secrets are
added).

Not verified yet:

- visual layout on a real 360–430 dp phone (Phase 4)
- file picker/download/open flow on Android
- timer accuracy across screen-off/background (uses wall-clock-independent
  `Timer.periodic`; acceptable for a study timer, revisit if Android throttles)
- server URL change followed by login against a second host

## 8. Known limitations

- `AttachmentsPanel` still uses the older v1 presentation and imports `dart:io`
  (temp files, `open_filex`), so `flutter build web` is not supported from this
  branch. Android/desktop builds are unaffected.
- Focus timer does not persist across app restarts; a session is logged only when
  the timer completes or the user taps log. Ambient audio is not implemented.
- `more_screen.dart` is unused; remove or repurpose it once the v2 shell is final.
- The theme requests the `Inter` font, which is not bundled; Flutter falls back
  silently.
- Subject/slot edits send explicit empty strings for optional text (the server
  applies its own trimming rules), and clearing a slot's room is not exposed in
  the edit form (create/update still accepts null from the API layer).
- Recycle Bin is an in-shell view; Profile and Settings are pushed routes.

## 9. Next phase (Phase 4)

1. Download `classmate-v2-apk` from run `43860338196`; sideload it.
2. Start PostgreSQL + `npm start` on the laptop; point the app at the LAN URL.
3. QA script: login, server URL switch, subject/slot extended fields, grade CRUD
   + GPA math, focus session log/stats, attachments upload/open/delete, recycle
   restore/purge, profile + password change, theme toggle, logout/login.
4. Generate a release keystore + repo secrets, rebuild signed APK.
5. Tag `v2.0.0` after QA sign-off; merge both v2 PRs before `main` (BL-002).
