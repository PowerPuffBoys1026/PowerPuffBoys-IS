# ClassMate — Client (Flutter)

One codebase that targets **Android, iOS, Web, Windows, and macOS**, talking to the
ClassMate REST API on `http://localhost:3000`.

## Requirements
- Flutter SDK (stable — built and tested with **3.47.7**)
- The backend running first: see [`../server/README.md`](../server/README.md)

## Run

```bash
flutter pub get

# Web (Edge) — works out of the box
flutter run -d edge

# Desktop (needs the Visual Studio "Desktop development with C++" workload)
flutter run -d windows

# Android (needs Android Studio + an emulator/device)
flutter run -d <device-id>
```

The API base URL defaults to `http://localhost:3000/api`. Override it with:

```bash
flutter run -d edge --dart-define=API_BASE_URL=http://192.168.1.10:3000/api
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
2. **Smart App Control / WDAC** can block Flutter's `font-subset.exe` during a
   **release** web build. Work around it with:
   ```bash
   flutter build web --release --no-tree-shake-icons
   ```
   Debug runs (`flutter run`) are unaffected.

## Demo account

`demo@classmate.app` / `demo12345` (created by `npm run seed` in `server/`).
