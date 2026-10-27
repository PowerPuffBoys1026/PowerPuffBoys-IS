# ClassMate — Server (REST API)

Node.js + Express + SQLite backend for the ClassMate app. Runs on
`http://localhost:3000`.

## Requirements
- Node.js 22 or newer (required by `better-sqlite3` 13)

## Setup

```bash
cd server
npm install
cp .env.example .env      # then edit JWT_SECRET
npm run seed              # optional: creates a demo account + sample data
npm run dev               # starts on http://localhost:3000 (auto-reload)
```

Demo credentials created by `npm run seed`:

```
email:    demo@classmate.app
password: demo12345
```

## Web app and mobile reminders

The dashboard is served at `http://localhost:3000/` and adapts to narrow phone screens
with a bottom navigation bar, touch-sized controls, and safe-area spacing. Deadline
reminders use browser notifications for unfinished work due within 24 hours. They are
checked while the website is open; they are not background push notifications. On
iPhone/iPad, add the site to the Home Screen and open that installed web app before
granting notification permission. Flashnote review intervals are saved on the current
browser/device.

## Scripts

| Command | What it does |
|---|---|
| `npm start` | Run the API |
| `npm run dev` | Run with auto-reload (`node --watch`) |
| `npm run seed` | Insert demo user, subjects, schedule and works |
| `npm run smoke` | End-to-end test on an isolated DB/port |

## API

Base URL `http://localhost:3000/api`.
Every route except `POST /auth/register` and `POST /auth/login` needs
`Authorization: Bearer <token>`.

| Method | Path | Notes |
|---|---|---|
| GET | `/health` | Liveness check & feature inventory |
| POST | `/auth/register` | `{ email, password (8+), fullName, studentNo?, course? }` |
| POST | `/auth/login` | `{ email, password }` |
| GET | `/auth/me` | Current user |
| PUT | `/auth/me` | Update `{ fullName, studentNo?, course? }` |
| GET/POST | `/subjects` | List / create |
| GET/PUT/DELETE | `/subjects/:id` | Read / update / delete |
| GET/POST | `/schedule` | `?day=0..6` filter; slot needs `subjectId, dayOfWeek, startTime, endTime` |
| PUT/DELETE | `/schedule/:id` | |
| GET/POST | `/attendance` | Mark `{ subjectId, slotId?, date, status }` |
| GET | `/attendance/summary` | Per-subject rate + safeMissesLeft cut margin + absence warning |
| GET/POST | `/works` | School works; filter `?status=&subjectId=&dueBefore=` |
| GET/PUT/DELETE | `/works/:id` | |
| PATCH | `/works/:id/status` | `{ status: todo\|doing\|done }` |
| GET | `/dashboard/today` | Today's classes + due-soon + warnings |
| GET/POST | `/study/sessions` | List recent focus logs / record new study session |
| GET | `/study/stats` | Focus minutes today/week, study streak days, by-subject stats |
| DELETE | `/study/sessions/:id` | Remove a study session log |
| GET/POST | `/grades` | List grading components / add component |
| PUT/DELETE | `/grades/:id` | Update / delete grade component |
| GET | `/grades/summary` | Semester GPA calculation, honors standing, target exam solver |
| GET/POST | `/notes` | List flashnotes (`?subjectId=`) / create flashnote |
| PUT/DELETE | `/notes/:id` | Update / delete flashnote |

**Error shape:** `{ "error": { "message": "…", "details": [ { "path", "message" } ] } }`
with status codes `400` validation, `401` auth, `404` not found, `409` conflict.

## Layout

```
server/
├── src/
│   ├── app.js              Express app (no listen) — testable
│   ├── index.js            starts the server
│   ├── config.js           env-driven config
│   ├── db.js               SQLite connection + schema
│   ├── seed.js             demo data
│   ├── middleware/         auth (JWT), error handling
│   ├── services/           attendance summary logic
│   ├── utils/              validate (zod), HttpError
│   └── routes/             auth, subjects, schedule, attendance, works, dashboard
├── scripts/smoke.js        end-to-end smoke test
└── data/                   SQLite files (gitignored)
```

## Data notes
- Dates are `YYYY-MM-DD`; times are `HH:MM` (24h); timestamps are ISO-8601.
- Attendance % = `present / (present + absent + late)`; `cancelled` is ignored.
- The absence threshold defaults to 20% (`ATTENDANCE_THRESHOLD` in `.env`).
- Every row is scoped to the JWT user — one account can never read another's data.
