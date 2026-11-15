# ClassMate v2 — Phase 2: Data Layer

**Status:** complete (client code compiles, analyze has 0 errors, 21/21 tests pass)
**Branch:** `feature/android-v2`
**Scope:** Flutter client only. No UI screens yet — Phase 3 consumes these APIs.

---

## 1. Goal

Give the existing Flutter client typed access to every v2 server feature before any
screen work starts:

- grades + GPA summary
- focus/study sessions + stats
- attachments (upload/download metadata)
- recycle bin
- extended profile/subject/schedule/note/work fields
- runtime-configurable LAN server address
- encrypted token storage

---

## 2. Files added

| File | Purpose |
|---|---|
| `lib/models/json.dart` | `asDouble` / `asInt` / `asLocalDate` lenient JSON coercion |
| `lib/models/grade.dart` | `GradeComponent`, `GradeSummaryComponent`, `SubjectGradeSummary`, `GradeSummary` |
| `lib/models/study_session.dart` | `StudySession`, `StudySubjectMinutes`, `StudyStats` |
| `lib/models/attachment.dart` | `Attachment` (+ `isImage`, `isPdf`, `extension`) |
| `lib/models/recycle_bin_item.dart` | `RecycleBinItem`, `RestoreResult` |
| `lib/state/settings_state.dart` | Runtime server URL + `normalizeServerUrl` |
| `lib/state/grades_state.dart` | Grades list + summary, CRUD wrapper |
| `lib/state/study_state.dart` | Sessions + stats, CRUD wrapper |
| `test/v2_models_test.dart` | 16 parsing/normalisation tests |

## 3. Files changed

| File | Change |
|---|---|
| `lib/api/api_client.dart` | Mutable `baseUrl` (getter/setter, trailing-slash trim), shared `_throwFor`, safe non-JSON error decoding, `getBytes()`, `postMultipart()` |
| `lib/api/api.dart` | `baseUrl`, `raw`; `updateProfile`, `changePassword`; subject `instructorEmail`/`officeHours`; slot `building`/`weekPattern` + `updateSlot`; `updateWork` (full PUT); note `subjectId` (list filter, create, update, clear); grades, study, attachments, recycle-bin endpoints |
| `lib/models/user.dart` | `yearLevel`, `createdAt` |
| `lib/models/subject.dart` | `instructorEmail`, `officeHours` |
| `lib/models/schedule_slot.dart` | `building`, `weekPattern` (defaults `every`) |
| `lib/models/note.dart` | Optional `subjectId`, `subjectCode`, `subjectTitle`, `subjectColor` |
| `lib/state/token_store.dart` | `flutter_secure_storage` with one-time migration from `shared_preferences` and graceful fallback |
| `lib/state/app_state.dart` | Extended subject/slot params, `editSlot`, `editWork`; error text uses `_api.baseUrl` |
| `lib/state/auth_state.dart` | `updateProfile`, `changePassword`; error text uses `_api.baseUrl` |
| `lib/state/notes_state.dart` | `subjectId` on create/update, `reset()` |
| `lib/screens/note_editor_screen.dart` | Preserves the note's subject link on save |
| `lib/main.dart` | Async bootstrap, `SettingsState.load()` before `runApp`, providers for `SettingsState`/`GradesState`/`StudyState`, reset all data states on logout |

---

## 4. API surface added (`lib/api/api.dart`)

| Method | Endpoint |
|---|---|
| `updateProfile` | `PUT /auth/me` |
| `changePassword` | `PUT /auth/me/password` |
| `grades`, `createGrade`, `updateGrade`, `deleteGrade`, `gradeSummary` | `/grades`, `/grades/:id`, `/grades/summary` |
| `studySessions`, `createStudySession`, `deleteStudySession`, `studyStats` | `/study/sessions`, `/study/sessions/:id`, `/study/stats` |
| `attachments`, `uploadAttachment`, `downloadAttachment`, `deleteAttachment` | `/attachments/:type/:id`, `/attachments/:id/download`, `/attachments/:id` |
| `recycleBin`, `restoreRecycleItem`, `deleteRecycleItem` | `/recycle_bin`, `/recycle_bin/:id/restore`, `/recycle_bin/:id` |
| `updateSlot` | `PUT /schedule/:id` |
| `updateWork` | `PUT /works/:id` |

Server contracts verified against `server/src/routes/*` and `server/src/models/*`
(camelCase JSON, `{ data: ... }` envelopes, `subjectId: null` clears optional
links, `weightPct`/`scorePct` are `NUMERIC` → parsed via `asDouble`).

---

## 5. Token storage

- Read order: secure storage → legacy SharedPreferences (migrate, then delete the
  prefs copy only after a successful secure write).
- Any platform error (e.g. Linux without libsecret) is caught and the value is
  read/written through `shared_preferences` so the app never hard-crashes.
- Same key as before (`classmate_token`), so upgrading users stay signed in.
- `clear()` removes the token from **both** stores.

## 6. Server address

`SettingsState.normalizeServerUrl` rules:

| Input | Result |
|---|---|
| `http://192.168.1.24:3000/api` | unchanged |
| `192.168.1.24:3000` | `http://192.168.1.24:3000/api` |
| `https://example.com/api/` | `https://example.com/api` |
| `http://10.0.0.5:8080/` | `http://10.0.0.5:8080/api` |
| `ftp://…`, `http://`, empty | `FormatException` |

Saved under SharedPreferences key `server_url`; `ApiClient.baseUrl` is switched
immediately, so login/register/in-app refresh use the new host without a rebuild.
`resetServerUrl()` falls back to the build-time `API_BASE_URL` dart-define.

---

## 7. Verification

```
cd client
flutter analyze     # 0 errors, 9 info lints (use_null_aware_elements, style only)
flutter test        # 21 tests, all pass
```

New coverage: numeric-string tolerance, null score handling, summary nesting,
session mode, stats totals, attachment helpers, recycle-bin dates, extended model
fields, and all `normalizeServerUrl` branches.

---

## 8. Known limitations / follow-ups

- No UI yet: the app still shows the v1 six-tab shell; grades/study/recycle/settings
  screens are Phase 3.
- File upload needs a file picker (`file_picker`) for the works/notes screens;
  the API layer is ready but unused.
- `flutter_secure_storage` is exercised by unit tests only; verify on a real
  Android device during Phase 4 (first write/read after install).
- `AppState.error`/`AuthState.error` now print the effective base URL, which helps
  when the LAN address is wrong.
- Existing `use_null_aware_elements` info lints remain (repo style predates the
  lint; non-fatal).

---

## 9. Next phase

Phase 3 — v2 UI parity:

1. navigation: 6 tabs → 5 + "More"
2. grades screen (components CRUD, target %, GPA summary)
3. focus timer (start/stop, log session, stats/streak)
4. recycle bin (restore/delete)
5. profile edit + change password
6. attachments on works/notes (picker + list + download/open)
7. settings screen (server URL)
8. extended fields in subject/schedule/note/work editors
