# ClassMate — Server (REST API)

Node.js + Express + PostgreSQL backend for the ClassMate app. Runs on
`http://localhost:3000`.

## Requirements
- Node.js 22 or newer
- PostgreSQL 14 or newer (tested on PostgreSQL 18)

## Setup

```bash
cd server
npm install
cp .env.example .env      # then set DATABASE_URL and JWT_SECRET

# 1. create the database (if missing) + apply db/schema.sql
npm run db:init

# 2. optional: creates a demo account + sample data
npm run seed

# 3. starts on http://localhost:3000 (auto-reload)
npm run dev
```

`npm run db:init` is safe to re-run: it creates the database named in
`DATABASE_URL` only when it is missing, then applies `db/schema.sql`
(`CREATE TABLE IF NOT EXISTS`, so existing tables are left alone).

Prefer doing it manually with `psql`? Run:

```bash
createdb classmate
psql -h localhost -U postgres -d classmate -f db/schema.sql
```

The default connection string is
`postgres://postgres:postgres@localhost:5432/classmate`. Override it in `.env`:

```ini
DATABASE_URL=postgres://user:password@localhost:5432/classmate
# PG_SCHEMA=public          # optional, defaults to public
# DATABASE_SSL=false        # set true for providers that require SSL
```

The tables and indexes are created automatically on first start.

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
| `npm run db:init` | Create the database if missing + apply `db/schema.sql` |
| `npm run seed` | Insert demo user, subjects, schedule and works |
| `npm run smoke` | End-to-end test on an isolated port and PostgreSQL schema |

`npm run smoke` creates a temporary PostgreSQL schema (for example `smoke_...`),
runs the checks against it, then drops it. It never touches the data in your
configured schema.

## API

Base URL `http://localhost:3000/api`.
Every route except `POST /auth/register` and `POST /auth/login` needs
`Authorization: Bearer <token>`.

| Method | Path | Notes |
|---|---|---|
| GET | `/health` | Liveness check |
| POST | `/auth/register` | `{ email, password (8+), fullName, studentNo?, course? }` |
| POST | `/auth/login` | `{ email, password }` |
| GET | `/auth/me` | Current user |
| GET/POST | `/subjects` | List / create |
| GET/PUT/DELETE | `/subjects/:id` | Read / update / delete |
| GET/POST | `/schedule` | `?day=0..6` filter; slot needs `subjectId, dayOfWeek, startTime, endTime` |
| PUT/DELETE | `/schedule/:id` | |
| GET/POST | `/attendance` | Mark `{ subjectId, slotId?, date, status }` |
| GET | `/attendance/summary` | Per-subject rate + absence warning |
| GET/POST | `/works` | School works; filter `?status=&subjectId=&dueBefore=` |
| GET/PUT/DELETE | `/works/:id` | |
| PATCH | `/works/:id/status` | `{ status: todo\|doing\|done }` |
| GET | `/dashboard/today` | Today's classes + due-soon + warnings |

**Error shape:** `{ "error": { "message": "…", "details": [ { "path", "message" } ] } }`
with status codes `400` validation, `401` auth, `404` not found, `409` conflict.

## Architecture (MVC)

The API follows a Model–View–Controller split:

| Layer | Folder | Responsibility |
|---|---|---|
| **Model** | `src/models/` | SQL and database access. No `req`/`res`. |
| **View** | `src/views/` | Shapes DB rows into the JSON payload sent to the client. |
| **Controller** | `src/controllers/` | Reads the request, validates input, calls models/services, sends the response. |
| Routes | `src/routes/` | Maps URLs to controller actions only. |
| Services | `src/services/` | Business rules shared across models (attendance summary). |
| Middleware | `src/middleware/` | Cross-cutting concerns (JWT auth, error handling). |

Request flow: `routes` → `controllers` → `models`/`services` → `views` → JSON response.

## Layout

```
server/
├── src/
│   ├── app.js              Express app (no listen) — testable
│   ├── index.js            starts the server
│   ├── config.js           env-driven config
│   ├── db.js               PostgreSQL pool + schema bootstrap
│   ├── seed.js             demo data
│   ├── routes/             URL → controller wiring only
│   ├── controllers/        HTTP handlers (req/res)
│   ├── models/             database queries per entity
│   ├── views/              JSON serializers (the API's "view")
│   ├── services/           shared business logic
│   ├── middleware/         auth (JWT), error handling
│   └── utils/              validate (zod), async handler, HttpError
├── db/schema.sql           tables, constraints and indexes
├── scripts/create-db.js    creates the database + applies the schema
├── scripts/smoke.js        end-to-end smoke test
└── .env.example            connection + auth settings template
```

## Data notes
- Dates are `YYYY-MM-DD`; times are `HH:MM` (24h); timestamps are ISO-8601.
- Attendance % = `present / (present + absent + late)`; `cancelled` is ignored.
- The absence threshold defaults to 20% (`ATTENDANCE_THRESHOLD` in `.env`).
- Every row is scoped to the JWT user — one account can never read another's data.
