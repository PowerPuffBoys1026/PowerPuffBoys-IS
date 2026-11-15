# Android v2 — Phase 1: Build Configuration & Release Signing

> Implementation record for Phase 1 of the plan in [`ANDROID.md`](ANDROID.md).
>
> **Status:** Complete — awaiting the first CI run.
> **Branch:** `feature/android-v2` (based on `a673846`)
> **Date:** 2026-11-15

---

## 1. Objective

Make the existing Flutter client produce an **installable, API-reachable Android APK**
from GitHub Actions, without installing the Android SDK or Android Studio on the
8 GB development laptop.

Phase 1 covers only build plumbing:

- Android `INTERNET` permission and cleartext HTTP for the LAN API.
- A Gradle memory cap that fits the laptop.
- App identity: label `ClassMate`, version `2.0.0+2`.
- Release signing from a keystore, with a debug fallback.
- A CI workflow that builds and uploads the APK.

v2 features (models, screens, runtime server URL) are **not** part of Phase 1.

---

## 2. Change Summary

| File | Change |
|---|---|
| `client/android/gradle.properties` | `-Xmx8G`/4G metaspace → `-Xmx2G`/1G metaspace |
| `client/android/app/src/main/AndroidManifest.xml` | Add `INTERNET`; label `ClassMate`; `usesCleartextTraffic="true"` |
| `client/pubspec.yaml` | `version: 1.0.0+1` → `2.0.0+2` |
| `client/android/app/build.gradle.kts` | Load `key.properties`; optional `release` signing config; debug fallback |
| `.github/workflows/android-build.yml` | New: analyze, test, build release APK, upload artifact |
| `docs/ANDROID.md` | Status bumped to Phase 1; §6.5/§7 corrected to match reality |

`applicationId` remains `com.powerpuffboys.classmate`, so v2 upgrades v1 installs
instead of installing alongside them.

---

## 3. Details

### 3.1 Gradle memory (`client/android/gradle.properties:1`)

Before:

```properties
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
```

After:

```properties
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError
```

The template value reserves 12 GB of JVM address space, which cannot fit this
machine. The cap only matters for optional local builds; CI has its own memory.

### 3.2 Manifest (`client/android/app/src/main/AndroidManifest.xml:2-8`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>

<application
    android:label="ClassMate"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:usesCleartextTraffic="true">
```

Why:

- **INTERNET** was only declared in the `debug` and `profile` manifests. A release
  APK could not open a socket at all.
- **usesCleartextTraffic** is required because the LAN API is plain `http://` and
  Android 9+ blocks cleartext by default. This is demo-only; remove it (or add a
  network security config allow-list) when the API is served over HTTPS.
- The label was the lowercase package-style `classmate`; it is now `ClassMate`.

### 3.3 Version (`client/pubspec.yaml:19`)

```yaml
version: 2.0.0+2
```

`2.0.0` becomes `versionName`; `2` becomes `versionCode`. The Dart SDK constraint
(`^3.13.5`) is unchanged and matches the pinned Flutter 3.47.7 toolchain.

### 3.4 Release signing (`client/android/app/build.gradle.kts:35-62`)

```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

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
        signingConfig = if (keystorePropertiesFile.exists()) {
            signingConfigs.getByName("release")
        } else {
            signingConfigs.getByName("debug")
        }
    }
}
```

Behaviour:

- With `client/android/key.properties` present → release APK signed by
  `client/android/app/release.jks`.
- Without it → debug signing, so local `flutter run --release` still works and CI
  still produces an installable demo APK.

Both `key.properties` and `*.jks` are already ignored by
`client/android/.gitignore` and the root `.gitignore`; no ignore changes were needed.

### 3.5 CI workflow (`.github/workflows/android-build.yml`)

Triggers:

- `push` to `main`, `feat/**`, `feature/**` when `client/**` or the workflow changes.
- `pull_request` touching `client/**`.
- Manual `workflow_dispatch`.

Job (`ubuntu-latest`, 30-minute timeout, `client/` working directory):

1. `actions/checkout@v4`
2. `actions/setup-java@v4` — Temurin JDK 17
3. `subosito/flutter-action@v2` — Flutter `3.47.7`, stable, cached
4. `flutter pub get`
5. `flutter analyze`
6. `flutter test`
7. Decode keystore — only when `HAS_KEYSTORE` is `true`
8. `flutter build apk --release --dart-define=API_BASE_URL=$API_BASE_URL`
9. `actions/upload-artifact@v4` → `classmate-v2-apk`

Two workflow-specific notes:

- **Secrets cannot be used directly in `if:`.** The job therefore exposes
  `HAS_KEYSTORE: ${{ secrets.KEYSTORE_BASE64 != '' }}` and gates the step with
  `if: env.HAS_KEYSTORE == 'true'`.
- **The Gradle wrapper is not committed** (`client/android/.gitignore` ignores
  `gradlew`, `gradlew.bat`, and `gradle-wrapper.jar`). Flutter 3.47.7 injects the
  wrapper at build time via `injectGradleWrapperIfNeeded`; the committed
  `gradle-wrapper.properties` pins Gradle `9.3.1`.

The API URL is not baked into the image deterministically yet: it comes from
repository variable `API_BASE_URL`, falling back to the placeholder
`http://192.168.1.24:3000/api`. Phase 2/3 adds a runtime override in the app.

---

## 4. Enabling signed, custom builds in CI

### 4.1 Create a keystore (one time, needs a JDK)

JDK 17 is **not** installed on the minimal laptop profile. Run this on a machine
with a JDK (or install one with
`winget install EclipseAdoptium.Temurin.17.JDK` first):

```powershell
cd client\android\app
keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 `
  -validity 10000 -alias classmate
```

Store the passwords in a password manager. Keep `release.jks`: losing it means
future updates cannot be signed with the same identity.

### 4.2 Push the secrets

From the repository root (after the changes are committed and the branch exists on
GitHub):

```powershell
$b64 = [Convert]::ToBase64String(
  [IO.File]::ReadAllBytes("client/android/app/release.jks"))
gh secret set KEYSTORE_BASE64 --body $b64
gh secret set KEYSTORE_PASSWORD --body "your-store-password"
gh secret set KEY_ALIAS --body "classmate"
gh secret set KEY_PASSWORD --body "your-key-password"
```

Optional, to avoid the placeholder URL:

```powershell
gh variable set API_BASE_URL --body "http://192.168.1.24:3000/api"
```

Use the laptop's current LAN address (`Get-NetIPAddress -AddressFamily IPv4`).
Changing it later only requires updating this variable and re-running the workflow,
until the in-app server URL setting exists.

### 4.3 Run the workflow

Push the branch (or use **Actions → Android build → Run workflow**). When green,
download `classmate-v2-apk` from the run summary and install it:

```powershell
adb devices                 # authorize the phone if prompted
adb install -r app-release.apk
adb shell dumpsys package com.powerpuffboys.classmate |
  Select-String versionName
```

---

## 5. Verification Performed

| Check | Command | Result |
|---|---|---|
| Dependency resolution | `flutter pub get` | Passed |
| Static analysis | `flutter analyze` | 0 errors; 7 pre-existing `use_null_aware_elements` **info** lints in `lib/api/api.dart:213-228` |
| Unit tests | `flutter test` | 5/5 passed |
| Workflow YAML | `yaml valid` (npm `yaml@2`) | Exit 0 |
| Gradle wrapper | inspected `gradle_utils.dart` + `gradle-wrapper.properties` | Injection confirmed; Gradle 9.3.1 |
| Toolchain | `flutter --version`, `adb version` | Flutter 3.47.7 / Dart 3.13.5; platform-tools 37.0.1 |

`flutter pub get` also rewrote four tracked, generated plugin registrant files
(`client/macos/...`, `client/windows/...`). Those unrelated diffs were reverted;
they are regenerated during builds.

No APK was built locally: the minimal profile intentionally has no JDK or Android
SDK. The first CI run is the APK verification.

---

## 6. Known Limitations

- The in-app **Server URL editor does not exist yet** (Phase 2/3). Until then the
  URL comes from `API_BASE_URL` at build time.
- Without keystore secrets the artifact is **debug-signed** — installable for the
  demo, not publishable.
- Cleartext HTTP remains enabled for the LAN demo.
- The launcher icon is still the Flutter default.
- Nothing has been committed or pushed; no CI run exists yet.
- `flutter build apk` was not executed locally, so the Kotlin DSL signing block is
  validated by inspection only until CI runs.

---

## 7. Acceptance Checklist

- [x] Gradle memory capped for an 8 GB machine
- [x] `INTERNET` permission in the release manifest
- [x] Cleartext HTTP allowed for the LAN API
- [x] Label `ClassMate`, version `2.0.0+2`
- [x] Keystore-based release signing with debug fallback
- [x] Workflow committed: analyze, test, build, upload
- [x] `flutter analyze` and `flutter test` green
- [x] Workflow YAML validates
- [ ] Repository secrets and `API_BASE_URL` configured
- [ ] First workflow run green
- [ ] APK installs; launcher shows `ClassMate`
- [ ] `versionName=2.0.0`, `versionCode=2`
- [ ] APK reaches `/api/health` at the configured URL

The last four items require a commit, a push, and a phone.

---

## 8. Rollback

```powershell
git checkout -- client/android/gradle.properties `
  client/android/app/src/main/AndroidManifest.xml `
  client/pubspec.yaml `
  client/android/app/build.gradle.kts
Remove-Item .github/workflows/android-build.yml
```

`docs/ANDROID.md` and this file are documentation-only and can stay.

---

## 9. Next

Phase 2 — v2 data layer: models (`grade`, `study_session`, `attachment`,
`recycle_bin_item`), API methods, state objects, `flutter_secure_storage`, extended
fields, and the runtime server URL setting. See [`ANDROID.md` §8-9](ANDROID.md).

---

## 10. Related Documents

| Doc | Content |
|---|---|
| [`ANDROID.md`](ANDROID.md) | Full Android v2 plan and phases |
| [`run-and-stop.md`](run-and-stop.md) | Starting/stopping the LAN API and client |
| [`TODO.md`](TODO.md) | Outstanding server/PR work (BL-002 merge order) |
| [`STORED_PROCEDURES.md`](STORED_PROCEDURES.md) | Migration 005 routines used by v2 endpoints |
