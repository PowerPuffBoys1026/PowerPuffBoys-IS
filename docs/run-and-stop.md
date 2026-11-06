# Running and Stopping ClassMate

ClassMate has two parts:

| Part | Technology | Default URL | Port |
|---|---|---|---|
| **API** | Node.js + Express + PostgreSQL | http://localhost:3000/api | `3000` |
| **Client** | Flutter (web / desktop / mobile) | http://127.0.0.1:8080 | `8080` |
| **Database** | PostgreSQL | `localhost:5432` | `5432` |

The API must be running before the client can log in or load data.

---

## 1. Prerequisites

| Tool | Version |
|---|---|
| Node.js | 22 or newer |
| npm | included with Node.js |
| PostgreSQL | 14 or newer |
| Flutter | 3.47 or newer (client only) |
| Chrome or Edge | current version (web client) |

Check them with:

```powershell
node -v
npm -v
psql --version
flutter --version
```

Windows desktop builds also need the Visual Studio **Desktop development with
C++** workload and **Developer Mode** enabled. The web build does not.

---

## 2. First-time setup

### 2.1 Database

Make sure PostgreSQL is running. Create the database:

```powershell
cd server
npm install
Copy-Item .env.example .env
notepad .env
npm run db:create
npm run db:init
```

Set these values in `server/.env`:

```ini
PORT=3000
JWT_SECRET=<long random string; see below>
CORS_ORIGIN=http://localhost:8080,http://127.0.0.1:8080
PGHOST=localhost
PGPORT=5432
PGDATABASE=classmate
PGMAINTENANCE_DB=postgres
PGUSER=postgres
PGPASSWORD=your-postgres-password
ATTENDANCE_THRESHOLD=20
```

Generate the JWT secret with
`node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"`.
The API will not start if `JWT_SECRET` is empty.

`server/.env` is gitignored. Never commit real passwords.

### 2.2 Seed demo data

```powershell
npm run seed
```

This also applies any pending migrations. It is safe to re-run.

Demo login:

```text
email:    demo@classmate.app
password: demo12345
```

### 2.3 Client packages

```powershell
cd ..\client
flutter pub get
```

If `flutter` is not on your `PATH`, use the full path, for example:

```powershell
C:\Users\ADMIN\flutter\bin\flutter.bat pub get
```

---

## 3. Run the app

Use two terminals.

### Terminal 1 — API

```powershell
cd server
npm run dev
```

Expected output:

```text
ClassMate API listening on http://localhost:3000
Health check:  http://localhost:3000/api/health
```

`npm run dev` restarts automatically when files change. Use `npm start` to run
without auto-reload.

### Terminal 2 — Flutter client

Web (recommended for demos):

```powershell
cd client
flutter run -d chrome --web-port 8080
```

Or with Edge:

```powershell
flutter run -d edge --web-port 8080
```

The app opens at **http://127.0.0.1:8080**.

Other targets:

```powershell
flutter devices                 # list devices
flutter run -d windows          # Windows desktop
flutter run -d <device-id>      # Android / iOS
```

To point the client at another API host:

```powershell
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://192.168.1.10:3000/api
```

### Verify the API

```powershell
Invoke-RestMethod http://localhost:3000/api/health
```

Expected:

```json
{ "status": "ok", "service": "classmate-api" }
```

---

## 4. Stop the app

### 4.1 Running in a terminal

| Process | How to stop |
|---|---|
| API (`npm run dev` / `npm start`) | Press `Ctrl+C` |
| Flutter (`flutter run`) | Press `q` then `Enter`, or `Ctrl+C` |
| Flutter, but leave the browser app open | Press `d` then `Enter` to detach |

### 4.2 Running in the background

Find the process using the port, then stop it:

```powershell
# API on port 3000
Get-NetTCPConnection -LocalPort 3000 -State Listen |
  Select-Object LocalAddress, LocalPort, OwningProcess

Stop-Process -Id (Get-NetTCPConnection -LocalPort 3000 -State Listen).OwningProcess
```

```powershell
# Flutter web server on port 8080
Get-NetTCPConnection -LocalPort 8080 -State Listen |
  Select-Object LocalAddress, LocalPort, OwningProcess

Stop-Process -Id (Get-NetTCPConnection -LocalPort 8080 -State Listen).OwningProcess
```

Closing the browser window alone may not stop the Flutter process.

### 4.3 Stop PostgreSQL

You normally do not need to stop PostgreSQL when stopping the app.

```powershell
# Requires an elevated terminal
Stop-Service postgresql-x64-18

# Start it again
Start-Service postgresql-x64-18
```

---

## 5. Configuration reference

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `3000` | API port |
| `JWT_SECRET` | — (required) | JWT signing secret; server refuses to start when empty |
| `JWT_EXPIRES_IN` | `7d` | Login token lifetime |
| `APP_TIMEZONE` | `Asia/Manila` | Time zone for "today", day-of-week and overdue checks |
| `CORS_ORIGIN` | local dev origins | Comma-separated browser origins allowed by CORS |
| `PGHOST` | `localhost` | PostgreSQL host |
| `PGPORT` | `5432` | PostgreSQL port |
| `PGDATABASE` | `classmate` | Application database |
| `PGMAINTENANCE_DB` | `postgres` | Database used by `db:create` |
| `PGUSER` | `postgres` | PostgreSQL user |
| `PGPASSWORD` | — | PostgreSQL password (keep local) |
| `PGPOOL_MAX` | `10` | Maximum PostgreSQL pool connections |
| `PGCONNECT_TIMEOUT_MS` | `5000` | Timeout for acquiring a connection |
| `PGSTATEMENT_TIMEOUT_MS` | `10000` | Per-query statement timeout |
| `ATTENDANCE_THRESHOLD` | `20` | Absence percentage that triggers a warning |

---

## 6. Troubleshooting

### `password authentication failed for user "postgres"`

`PGPASSWORD` in `server/.env` does not match the PostgreSQL server. Update it
with the correct password, then restart the API.

### `database "classmate" does not exist`

```powershell
cd server
npm run db:create
npm run seed
```

### `Port 3000 is already in use` / `Port 8080 is already in use`

Find and stop the old process:

```powershell
Get-NetTCPConnection -LocalPort 3000,8080 -State Listen |
  Select-Object LocalPort, OwningProcess

Stop-Process -Id <OwningProcess>
```

Or use different ports:

```powershell
$env:PORT=3001; npm run dev
flutter run -d chrome --web-port 8081 --dart-define=API_BASE_URL=http://localhost:3001/api
```

### `Building with plugins requires symlink support`

Enable Developer Mode on Windows:

```powershell
start ms-settings:developers
```

For a web-only run on a machine where Developer Mode cannot be enabled, the
temporary workaround is:

```powershell
Rename-Item client\windows client\windows.disabled
cd client
flutter pub get
flutter run -d chrome --web-port 8080
# restore after the app starts
Rename-Item client\windows.disabled client\windows
```

Do not commit the renamed folder.

### `flutter: command not found`

Add Flutter to the session `PATH`:

```powershell
$env:Path = 'C:\Users\ADMIN\flutter\bin;' + $env:Path
flutter --version
```

### Windows release web build blocked by Smart App Control

```powershell
flutter build web --release --no-tree-shake-icons
```

Debug runs (`flutter run`) are unaffected.
