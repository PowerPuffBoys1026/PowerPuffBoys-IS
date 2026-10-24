# ClassMate — Client (Flutter)

Flutter client for **Android, iOS, Windows, and macOS**, talking to the ClassMate REST
API on `http://localhost:3000`. The browser app is served by the Node server; do not run
the legacy Flutter web target.

## Requirements
- Flutter SDK (stable — built and tested with **3.47.7**)
- The backend running first: see [`../server/README.md`](../server/README.md)

## Run

```bash
flutter pub get

# Desktop (needs the Visual Studio "Desktop development with C++" workload)
flutter run -d windows

# Android (needs Android Studio + an emulator/device)
flutter run -d <device-id>
```

The API base URL defaults to `http://localhost:3000/api`. Override it with:

```bash
flutter run -d <device-id> --dart-define=API_BASE_URL=http://192.168.1.10:3000/api
```

## Checks

```bash
flutter analyze     # must be clean
flutter test        # unit tests for models + formatters
```

## Project layout

```
lib/
├── main.dart           app entry, providers, auth gate
├── config.dart         API base URL (dart-define)
├── theme.dart          Material 3 theme
├── api/                ApiClient (http) + typed Api
├── models/             User, Subject, ScheduleSlot, Attendance, SchoolWork, Dashboard
├── state/              AuthState, AppState, TokenStore
├── screens/            login, register, home shell, dashboard, schedule,
│                       attendance, works, subjects
└── utils/              color/date/time formatting helpers
```

## Windows notes

Two machine-level settings can get in the way; both are fixable:

1. **Developer Mode** — building with plugins needs symlink support:
   *Settings → System → For developers → Developer Mode → On.*
2. **Smart App Control / WDAC** can block Flutter build tools. Use a debug run while
   diagnosing the restriction.

## Demo account

`demo@classmate.app` / `demo12345` (created by `npm run seed` in `server/`).
