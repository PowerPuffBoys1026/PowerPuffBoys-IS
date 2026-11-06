# ClassMate — Server (REST API)

Node.js + Express + PostgreSQL backend for the ClassMate app. Runs on
`http://localhost:3000`.

## Requirements
- Node.js 22 or newer
- PostgreSQL running on `localhost:5432` (or configure another connection in `.env`)

## Setup

```bash
cd server
npm install
copy .env.example .env    # Windows; then set JWT_SECRET and PGPASSWORD
npm run db:create         # creates the PostgreSQL database once
npm run db:init           # applies pending migrations (also runs on startup)
npm run seed              # optional: creates a demo account + sample data
npm run dev               # starts on http://localhost:3000 (auto-reload)
```

`JWT_SECRET` is required — the server refuses to start without it. Generate one with:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

Browser origins allowed by CORS come from `CORS_ORIGIN` (comma-separated).
`POST /auth/register` and `POST /auth/login` are limited to 20 attempts per
15 minutes per IP.

The API applies pending SQL migrations from `server/migrations/` on startup.
To import the existing local SQLite data, create the database and run
`npm run db:migrate:sqlite` before starting the API. The import is transactional,
refuses a non-empty PostgreSQL database, and leaves the SQLite file unchanged.

Demo credentials created by `npm run seed`:

```
email:    demo@classmate.app
password: demo12345
```

## Scripts

| Command | What it does |
|---|---|
| `npm start` | Run the API |
| `npm run dev` | Run with auto-reload (`node --watch`) |
| `npm run seed` | Insert demo user, subjects, schedule and works |
| `npm run db:create` | Create the PostgreSQL database configured in `.env` |
| `npm run db:init` / `npm run migrate` | Apply pending migrations |
| `npm run db:migrate:sqlite` | Import `data/classmate.db` into an empty PostgreSQL database |
| `npm test` | Unit + API integration tests on a throwaway database |
| `npm run smoke` | End-to-end test on an isolated DB/port |

`npm test` uses Node's built-in test runner. Unit tests cover validation and
time-zone helpers; API tests create and drop a temporary PostgreSQL database and
never touch application data. GitHub Actions runs both `npm test` and
`npm run smoke` against a PostgreSQL service on every push and pull request.

## API

Base URL `http://localhost:3000/api`.
Every route except `POST /auth/register` and `POST /auth/login` needs
`Authorization: Bearer <token>`.

| Method | Path | Notes |
|---|---|---|
| GET | `/health` | Liveness + database check (`503` when PostgreSQL is down) |
| POST | `/auth/register` | `{ email, password (8–72), fullName, studentNo?, course? }` |
| POST | `/auth/login` | `{ email, password }` — rate limited |
| GET | `/auth/me` | Current user |
| GET/POST | `/subjects` | List / create |
| GET/PUT/DELETE | `/subjects/:id` | Read / update / delete |
| GET/POST | `/schedule` | `?day=0..6` filter; slot needs `subjectId, dayOfWeek, startTime, endTime` |
| PUT/DELETE | `/schedule/:id` | `endTime` must be later than `startTime` |
| GET/POST | `/attendance` | Mark `{ subjectId, slotId?, date, status }`; `slotId` must belong to the subject |
| GET | `/attendance/summary` | Per-subject rate + absence warning |
| PUT/DELETE | `/attendance/:id` | Cannot create a duplicate session |
| GET/POST | `/works` | School works; filter `?status=&subjectId=&dueBefore=` |
| GET/PUT/DELETE | `/works/:id` | |
| PATCH | `/works/:id/status` | `{ status: todo\|doing\|done }` |
| GET/POST | `/notes` | Notes; filter `?search=&tag=&pinned=true\|false` |
| GET/PUT/DELETE | `/notes/:id` | Read / update / delete |
| PATCH | `/notes/:id/pin` | Toggle the pinned flag |
| GET | `/dashboard/today` | Today's classes + due-soon + warnings |

List endpoints (`/subjects`, `/schedule`, `/attendance`, `/works`, `/notes`) accept
optional `?limit=1..100&offset=0` pagination. Every read and write is scoped to the
authenticated user, so another user's resource IDs return `404` rather than leaking data.

**Error shape:** `{ "error": { "message": "…", "details": [ { "path", "message" } ] } }`
with status codes `400` validation, `401` auth, `404` not found, `409` conflict,
`413` body too large, `429` too many auth attempts.

## Architecture (MVC)

The API follows a Model–View–Controller split:

| Layer | Folder | Responsibility |
|---|---|---|
| **Model** | `src/models/` | SQL and database access. No `req`/`res`. |
| **View** | `src/views/` | Shapes DB rows into the JSON payload sent to the client. |
| **Controller** | `src/controllers/` | Reads the request, validates input, calls models/services, sends the response. |
| Routes | `src/routes/` | Maps URLs to controller actions only. |
| Services | `src/services/` | Business rules shared across models (attendance summary). |
| Middleware | `src/middleware/` | Cross-cutting concerns (JWT auth, rate limiting, error handling). |

Request flow: `routes` → `controllers` → `models`/`services` → `views` → JSON response.

## Layout

```
server/
├── src/
│   ├── app.js              Express app (no listen) — testable
│   ├── index.js            starts the server + graceful shutdown
│   ├── config.js           env-driven config
│   ├── db.js               PostgreSQL pool + type parsers
│   ├── migrate.js          migration runner (`npm run db:init`)
│   ├── migrate-sqlite.js   one-time import from the old SQLite database
│   ├── seed.js             demo data
│   ├── routes/             URL → controller wiring only
│   ├── controllers/        HTTP handlers (req/res)
│   ├── models/             database queries per entity
│   ├── views/              JSON serializers (the API's "view")
│   ├── services/           shared business logic
│   ├── middleware/         auth (JWT), rate limiting, error handling
│   └── utils/              validate (zod), parse (ids/query), dates, HttpError
├── migrations/             ordered SQL files applied once
├── scripts/
│   ├── create-db.js        creates the PostgreSQL database
│   └── smoke.js            end-to-end smoke test
├── test/                   unit + API integration tests
└── data/                   legacy SQLite files (gitignored)
```

## Data notes
- `attendance_records.date` is a real `date`; schedule times are `time`;
  `school_works.due_at` is `timestamptz`.
- API dates are `YYYY-MM-DD`; times are `HH:MM` (24h); timestamps are ISO-8601.
- "Today", overdue checks and day-of-week use `APP_TIMEZONE` (default `Asia/Manila`).
- Attendance % = `present / (present + absent + late)`; `cancelled` is ignored.
- The absence threshold defaults to 20% (`ATTENDANCE_THRESHOLD` in `.env`).
- Every row is scoped to the JWT user — one account can never read another's data.
