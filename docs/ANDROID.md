# ClassMate v2 — Android Build Plan

> Target: a real Android app for **ClassMate 2.0**, built from the existing Flutter
> client, talking to the ClassMate API on a LAN development laptop, with the APK
> compiled in GitHub Actions.
>
> **Status:** Phase 1 — implemented, pending first CI run.
> **Last updated:** 2026-11-15.

---

## 1. Decisions

| Decision | Choice | Why |
|---|---|---|
| Client | Reuse `client/` (Flutter/Dart) | ~2,900 lines already wired to the API; one codebase stays |
| Backend | `server/` + PostgreSQL on the dev laptop, reached over LAN | Matches the proposal's "local development server" scope; zero hosting cost |
| APK build | GitHub Actions (`ubuntu-latest`) | The dev laptop has 8 GB RAM; no Android Studio/emulator/Gradle load locally |
| Scope | Full v2 parity | Grades, focus timer, attachments, recycle bin, extended fields |
| Out of scope | Reminders, Play Store, iOS/macOS, offline sync, cloud hosting | Deferred — see §12 |

Whichever build path is used, **Android Studio is not required**. Neither is the
Android emulator, Visual Studio's C++ workload, or Xcode.

---

## 2. Architecture

```
┌──────────────────────────┐        Wi-Fi (same LAN)        ┌────────────────────────────┐
│  Android phone           │  http://192.168.x.x:3000/api   │  Windows dev laptop        │
│  ClassMate 2.0 APK       │ ─────────────────────────────▶ │  Node 22 + Express :3000   │
│  (Flutter release build) │        Bearer <JWT>            │            │               │
└──────────────────────────┘                                │            ▼               │
                                                            │  PostgreSQL :5432          │
                                                            └────────────────────────────┘
```

Notes:

- `server/src/index.js` calls `app.listen(port)` without a host, so Node listens on
  all interfaces. Only the Windows Firewall needs an inbound rule for TCP 3000.
- PostgreSQL stays bound to `localhost`; only Node talks to it.
- Mobile HTTP clients do not send a browser `Origin` header, so CORS is not the
  blocker for the APK — the firewall is.
- The laptop's LAN IP can change. The app therefore needs a **runtime Server URL
  setting**; the IP is not baked into the APK.

---

## 3. Toolchain

### 3.1 Local machine — minimal profile (~2 GB)

Used for coding, `flutter analyze`, `flutter test`, web preview, and sideloading.

| Tool | Version | Install | Size |
|---|---|---|---|
| Git for Windows | latest | PortableGit zip → `C:\dev\PortableGit` | ~70 MB |
| Flutter SDK | **3.47.7 stable** | official Windows zip → `C:\dev\flutter` | ~1.5 GB |
| Android `platform-tools` | latest | Google zip → `C:\Android\platform-tools` | ~40 MB |
| VS Code + Flutter extension | optional | any editor works | ~300 MB |

Result: `flutter run -d chrome` works immediately; `adb install` sideloads CI-built APKs.

### 3.2 Local machine — full local build profile (optional, adds ~5 GB)

Only needed if we want on-device hot reload without waiting on CI:

| Tool | Install |
|---|---|
| Eclipse Temurin **JDK 17** | `winget install EclipseAdoptium.Temurin.17.JDK` |
| Android `cmdline-tools` | zip → `C:\Android\cmdline-tools\latest` |
| SDK packages | `sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"` |

Also cap Gradle memory (see §6.2) — the repo currently sets `-Xmx8G`, which will
thrash an 8 GB laptop.

### 3.3 CI runner

`ubuntu-latest` provides the JDK and Android SDK. The workflow installs Flutter and
builds the APK. Nothing heavy stays on Windows.

### 3.4 Explicitly NOT installed

Android Studio · Android emulator · Visual Studio "Desktop development with C++" ·
Xcode.

---

## 4. First-time setup (Windows)

Run PowerShell **without** elevation where possible. Paths avoid spaces because
Gradle and native build scripts quote poorly around them.

### 4.1 Git (portable, user-scoped)

```powershell
New-Item -ItemType Directory -Force C:\dev | Out-Null
# Download the latest PortableGit 64-bit self-extracting archive from the
# git-for-windows releases page, then:
& "C:\dev\PortableGit-*-64-bit.7z.exe" -o"C:\dev\PortableGit" -y
$env:Path = "C:\dev\PortableGit\cmd;$env:Path"
git --version
[Environment]::SetEnvironmentVariable(
  "Path",
  [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\dev\PortableGit\cmd",
  "User")
```

### 4.2 Flutter SDK

```powershell
# Download from https://docs.flutter.dev/release/archive (Windows, stable 3.47.7)
Expand-Archive C:\dev\flutter_windows_3.47.7-stable.zip -DestinationPath C:\dev
$env:Path = "C:\dev\flutter\bin;$env:Path"
flutter --version
[Environment]::SetEnvironmentVariable(
  "Path",
  [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\dev\flutter\bin",
  "User")
flutter config --no-analytics
flutter doctor
```

`flutter doctor` is expected to warn that Android Studio/toolchain is missing on the
minimal profile. **That warning is cosmetic** when the APK is built in CI.

### 4.3 Android platform-tools

```powershell
# https://dl.google.com/android/repository/platform-tools-latest-windows.zip
Expand-Archive platform-tools-latest-windows.zip -DestinationPath C:\Android
$env:Path = "C:\Android\platform-tools;$env:Path"
adb version
[Environment]::SetEnvironmentVariable(
  "Path",
  [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\Android\platform-tools",
  "User")
```

### 4.4 Client checks

```powershell
cd client
flutter pub get
flutter analyze
flutter test
```

### 4.5 Optional: full local Android SDK

```powershell
# cmdline-tools zip → C:\Android\cmdline-tools\latest (folder must be named "latest")
$env:ANDROID_HOME = "C:\Android"
flutter config --android-sdk C:\Android
C:\Android\cmdline-tools\latest\bin\sdkmanager.bat `
  "platform-tools" "platforms;android-36" "build-tools;36.0.0"
flutter doctor --android-licenses
flutter doctor
```

---

## 5. LAN server setup

### 5.1 Apply migrations and start the API

```powershell
cd server
npm install
Copy-Item .env.example .env    # once; fill JWT_SECRET and PGPASSWORD
npm run db:create
npm run migrate
npm run seed
npm run dev
```

The v2 routes (`/api/study`, `/api/grades`, `/api/attachments`, `/api/recycle_bin`)
depend on **migration 005**. Confirm the health check reports the database:

```powershell
Invoke-RestMethod http://localhost:3000/api/health
```

### 5.2 Find the laptop's LAN address

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -eq 'Dhcp' } |
  Select-Object InterfaceAlias, IPAddress
```

Example: `http://192.168.1.24:3000/api`.

### 5.3 Allow the port through Windows Firewall (elevated, once)

```powershell
New-NetFirewallRule -DisplayName "ClassMate API 3000" `
  -Direction Inbound -Protocol TCP -LocalPort 3000 `
  -Action Allow -Profile Private
```

### 5.4 Verify from the phone

Open `http://<laptop-ip>:3000/api/health` in the phone's browser. It should return
`{"status":"ok",...}`.

If it does not:

- Phone and laptop are not on the same network.
- The Wi-Fi has **AP/client isolation** (common on campus/guest networks) — use the
  phone's hotspot with the laptop connected to it.
- The firewall rule is on the wrong profile (Private vs Public).

### 5.5 Runtime Server URL (required)

Because the IP changes, the app must let the user set it at runtime:

- `shared_preferences` key, e.g. `server_url`.
- Default from `--dart-define=API_BASE_URL=...`; the login/settings screen shows and
  edits it.
- On connection failure, surface a "Server unreachable — change server URL" action
  instead of a dead-end error.

`client/lib/config.dart` keeps the build-time default; a new `SettingsState` owns the
runtime override.

---

## 6. Android configuration changes

### 6.1 Manifest (`client/android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>

<application
    android:label="ClassMate"
    android:usesCleartextTraffic="true" ... >
```

The release manifest currently has **no INTERNET permission** (only debug/profile
do), so a release APK cannot reach any API. `usesCleartextTraffic` is **demo-only**;
it is required because the LAN API is plain HTTP. When the API moves to HTTPS,
remove it (or replace it with a `network_security_config.xml` allow-list).

### 6.2 Gradle memory (`client/android/gradle.properties`)

```properties
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=1G -XX:+HeapDumpOnOutOfMemoryError
```

The template value (`-Xmx8G -XX:MaxMetaspaceSize=4G`) cannot fit in this laptop's
8 GB.

### 6.3 App identity

- `applicationId`: keep `com.powerpuffboys.classmate` so v2 replaces v1 installs.
- `version`: `2.0.0+2` in `client/pubspec.yaml`.
- Label: `ClassMate`; refresh the launcher icon before release.

### 6.4 Release signing

```powershell
keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 `
  -validity 10000 -alias classmate
```

Store `release.jks` at `client/android/app/release.jks` (gitignored) and create
`client/android/key.properties` (gitignored):

```ini
storeFile=release.jks
storePassword=...
keyAlias=classmate
keyPassword=...
```

Kotlin DSL snippet for `client/android/app/build.gradle.kts`:

```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}
```

Without secrets, CI falls back to debug signing — installable for the demo, not
suitable for Play.

### 6.5 Gitignore

No change needed: `client/android/.gitignore` already ignores
`key.properties`, `**/*.jks`, and `**/*.keystore`, and the root `.gitignore`
also ignores `*.jks` / `*.keystore`.

---

## 7. GitHub Actions APK workflow

New file: `.github/workflows/android-build.yml`.

The workflow is committed at
[`.github/workflows/android-build.yml`](../.github/workflows/android-build.yml) —
treat that file as the source of truth: Flutter 3.47.7, Temurin JDK 17,
`client/` working directory, artifact `classmate-v2-apk`.

Pipeline: checkout → Java 17 → Flutter 3.47.7 (cached) → `pub get` → `analyze` →
`test` → optional keystore decode → `flutter build apk --release
--dart-define=API_BASE_URL=...` → upload artifact.

Repository secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
`KEY_PASSWORD`. Optional repository variable: `API_BASE_URL`.

> Note: GitHub Actions forbids referencing `secrets` directly inside `if:`, so the
> keystore step is gated by a job-level `HAS_KEYSTORE` env var. Verify the
> `subosito/flutter-action` tag/inputs against its current release before relying
> on the build; Flutter must match the Dart constraint in `client/pubspec.yaml`.

Downloading and installing an artifact:

```powershell
adb devices                 # authorize the phone if prompted
adb install -r app-release.apk
```

---

## 8. v2 parity matrix

| Feature | v2 web UI | Flutter client today | Android v2 target |
|---|---|---|---|
| Auth (login/register) | yes | yes | keep |
| Profile edit + password | yes | no | add |
| Subjects CRUD | yes | yes | keep |
| Subject `instructorEmail`, `officeHours` | yes | no | add |
| Schedule CRUD + day view | yes | yes | keep |
| Schedule `building`, `weekPattern`, weekly grid | yes | partial | add |
| Attendance marking + summary | yes | yes | keep |
| School works CRUD + status | yes | yes | keep |
| Notes CRUD + pin | yes | yes | keep |
| Note ↔ subject link | yes | no | add |
| Attachments (works/notes) | yes | no | add |
| Dashboard today | yes | yes | keep |
| Grades components + GPA/standing | yes | no | add |
| Focus timer + ambient audio | yes | no | add |
| Study stats + streak | yes | no | add |
| Recycle bin (restore/purge) | yes | no | add |
| Midnight Glass theme | yes | yes | keep |
| Reminders/notifications | no | no | out of scope |

### 8.1 API endpoints to add to `client/lib/api/api.dart`

| Method | Path | Purpose |
|---|---|---|
| GET/POST | `/grades` | List / create grade components |
| PUT/DELETE | `/grades/:id` | Update / trash a component |
| GET | `/grades/summary` | Per-subject %, GPA, letter, standing |
| GET/POST | `/study/sessions` | List / log focus sessions |
| DELETE | `/study/sessions/:id` | Trash a session |
| GET | `/study/stats` | Today/week/all-time, streak, by subject |
| GET | `/attachments/:resourceType` | List for `works` / `notes` |
| GET/POST | `/attachments/:resourceType/:resourceId` | List / upload (multipart) |
| GET | `/attachments/:id/download` | Download |
| DELETE | `/attachments/:id` | Delete |
| GET | `/recycle_bin` | List trashed items |
| POST | `/recycle_bin/:id/restore` | Restore |
| DELETE | `/recycle_bin/:id` | Permanently delete |
| GET/PUT | `/auth/me` | Profile read / update |
| PUT | `/auth/me/password` | Change password |

### 8.2 New Dart files

```
lib/models/grade.dart              GradeComponent, GradeSummary, SubjectGradeSummary
lib/models/study_session.dart      StudySession, StudyStats
lib/models/attachment.dart         Attachment
lib/models/recycle_bin_item.dart   RecycleBinItem
lib/state/settings_state.dart      runtime server URL
lib/state/grades_state.dart
lib/state/study_state.dart
lib/screens/grades_screen.dart
lib/screens/focus_screen.dart
lib/screens/recycle_bin_screen.dart
lib/screens/profile_screen.dart
lib/screens/server_settings_screen.dart
lib/widgets/attachments_sheet.dart
lib/widgets/grade_component_tile.dart
```

Extend: `user.dart` (`yearLevel`), `subject.dart` (`instructorEmail`,
`officeHours`), `schedule_slot.dart` (`building`, `weekPattern`), `note.dart`
(`subjectId`), `token_store.dart` (→ `flutter_secure_storage`).

### 8.3 New packages (`client/pubspec.yaml`)

| Package | Use |
|---|---|
| `flutter_secure_storage` | JWT at rest |
| `audioplayers` | ambient focus loops |
| `file_picker` | attachment upload (SAF, no storage permission needed) |
| `path_provider` | download temp directory |
| `open_filex` | open a downloaded attachment |
| `shared_preferences` | already present; server URL + settings |

Ambient loops must be bundled **royalty-free/CC0** assets.

### 8.4 Navigation

The web v2 has 8 views; the current shell has 6. Nine bottom-bar destinations do not
fit. Target:

**Bottom bar:** Today · Timetable · Works · Focus · More
**More sheet/screen:** Attendance · Subjects · Grades · Notes · Recycle Bin · Profile · Server settings
**Wide screens:** keep the `NavigationRail` with all destinations.

---

## 9. Phases

| Phase | Work | Deliverable | Est. |
|---|---|---|---|
| **0** | Toolchain, branch, `flutter analyze`/`test`, web preview | Working local Flutter + `feature/android-v2` branch | 0.5 d |
| **1** | Manifest (INTERNET/cleartext), Gradle memory, signing, CI workflow, app label/version | CI-produced installable APK | 1 d |
| **2** | Models, API methods, state, secure storage, extended fields | v2 data layer compiling and tested | 2–3 d |
| **3** | Grades, Focus, Recycle Bin, Profile, attachments, navigation, theme polish | Full v2 UI parity | 3–4 d |
| **4** | Device QA, release tag, docs, demo script | `v2.0.0` APK + QA sign-off | 1–2 d |

Branching: `feature/android-v2` off the v2 integration branch; PRs target `main` only
after `feat/v2-ui-ux-integration` and `feat/db-stored-procedures-security` are merged
(see `docs/TODO.md` BL-002). Never push directly to `main`.

---

## 10. QA checklist (on the phone)

- [ ] Install the CI APK with `adb install -r`.
- [ ] Login with `demo@classmate.app` / `demo12345`; token survives app restart.
- [ ] Change server URL to a wrong value → clear error + recoverable.
- [ ] Subjects: create, edit, delete; extended fields persist.
- [ ] Schedule: add/edit/delete; day view and weekly grid.
- [ ] Attendance: mark present/absent/late/cancelled; summary and warning.
- [ ] Works: create, change status, filter, delete (goes to recycle bin).
- [ ] Notes: create, edit, pin, link a subject, attach a file.
- [ ] Grades: add weighted components; GPA/standing and needed-on-remaining update.
- [ ] Focus: timer survives backgrounding/lock; session logged; ambient audio plays.
- [ ] Attachments: upload, list, download, open, delete.
- [ ] Recycle bin: restore and permanently delete.
- [ ] Profile: edit fields, change password.
- [ ] Rotation, small screen, airplane mode, and a 2-hour demo run.
- [ ] `flutter analyze` clean; `flutter test` green; server `npm test` + `npm run smoke` green.

---

## 11. Troubleshooting

| Symptom | Fix |
|---|---|
| `flutter: command not found` | Add `C:\dev\flutter\bin` to the session `PATH`, then reopen the terminal |
| `cmdline-tools component is missing` (full local profile) | Install cmdline-tools into `C:\Android\cmdline-tools\latest` |
| Gradle OOM / laptop freezes | Keep APK builds in CI; set `-Xmx2G` if building locally |
| APK cannot reach the API | INTERNET permission present? Phone and laptop on the same subnet? Firewall rule on the right profile? Server URL correct? |
| `CLEARTEXT communication ... not permitted` | `android:usesCleartextTraffic="true"` (demo) or serve HTTPS |
| Phone browser cannot open `/api/health` | AP isolation or firewall; try the phone hotspot |
| `adb devices` shows `unauthorized` | Accept the USB debugging prompt on the phone |
| `Install failed: INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Uninstall the old app (different signing key), then reinstall |
| CI `flutter pub get` fails on SDK constraint | Align the workflow's Flutter version with `client/pubspec.yaml` |
| Release build uses debug signing | Add the four keystore secrets; check the workflow decode step |

---

## 12. Out of scope (this iteration)

- Local notifications / reminders for classes and deadlines.
- Google Play publishing and store review.
- iOS/macOS builds (require a Mac).
- Offline-first storage and background sync.
- Cloud deployment (Render + Neon is the documented fallback if the app must work
  away from the laptop; `DATABASE_URL` is already supported by `server/src/config.js`).
- Real-time chat, shared classes, and image/photo uploads beyond attachments.

---

## 13. Related documents

| Doc | Content |
|---|---|
| [`docs/ANDROID_PHASE1.md`](ANDROID_PHASE1.md) | Phase 1 record: manifest, Gradle, signing, CI workflow |
| [`docs/ANDROID_PHASE2.md`](ANDROID_PHASE2.md) | Phase 2 record: models, API endpoints, settings, secure storage |
| [`docs/ANDROID_PHASE3.md`](ANDROID_PHASE3.md) | Phase 3 record: grades/focus/recycle/profile/settings/attachments UI |
| [`docs/plan.md`](plan.md) | Original technical plan, ERD, API reference |
| [`docs/kickoff.md`](kickoff.md) | Project brief and setup |
| [`docs/run-and-stop.md`](run-and-stop.md) | Running/stopping the API, client, database |
| [`docs/TODO.md`](TODO.md) | Outstanding v2 server/PR work |
| [`docs/STORED_PROCEDURES.md`](STORED_PROCEDURES.md) | Migration 005 routines used by v2 endpoints |
| [`client/README.md`](../client/README.md) | Flutter client notes |
