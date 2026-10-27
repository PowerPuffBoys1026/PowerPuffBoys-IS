# ClassMate — Project Kickoff & Setup

**Group 7 (PowerPuffBoys)** · Started 2026-10-12 · 4-week cycle · Demo **Nov 9, 2026**

> **Read me first.** This one file is the project brief *and* the setup guide. Everything
> you need to understand what we're building and get it running is here. Deeper details
> live in the linked docs at the bottom.

---

## 1. What we're building

**ClassMate** is a cross-platform study app for students. It puts the three things
students constantly lose track of in one place:

1. **Schedule** — your weekly class timetable.
2. **Attendance** — one-tap marking, with your absence % per subject and a warning when
   you're close to a cutoff.
3. **School works** — assignments, quizzes, and exams with due dates and reminders.

**One account, three platforms.** We build a single Flutter codebase that runs as a
mobile app, a web app, and a desktop app, all talking to one REST API.

### Why three platforms (the reason we can defend in the demo)

| Platform | Role |
|---|---|
| **Mobile** | Everyday device — reminders fire here, fast one-tap attendance |
| **Web** | No-install access from a shared or lab computer |
| **Desktop** | Big-screen view — full weekly timetable grid and reports |

### Core objectives (from the proposal)
- A unified cross-platform client — Mobile (iOS/Android), Web, Desktop (Windows/macOS).
- A functional **RESTful API** running on `localhost`.
- **Local data persistence** with central management across all platforms.

---

## 2. Tech stack

| Layer | Choice |
|---|---|
| Client | **Flutter** (Dart) — Android, iOS, Web, Windows, macOS from one codebase |
| State / API | `provider`, `http`/`dio`, `flutter_secure_storage`, `flutter_local_notifications`, `table_calendar` |
| Backend | **Node.js 22+** + **Express** (JavaScript) |
| Database | **SQLite** (server-side, via `better-sqlite3`) |
| Auth | **JWT** + `bcryptjs` password hashing |
| Tooling | VS Code, Android Studio, Postman/Thunder Client, DB Browser for SQLite |

> ⚠️ **Node.js 22 or newer is required.** `better-sqlite3` 13 has no builds for Node 20.
> Run `node -v` — if it's below 22, install the current LTS before you start.

---

## 3. Repository layout

```
PowerPuffBoys/
├── client/            Flutter app (all platforms)   ← scaffolded + compiles for web
├── server/            Node + Express REST API        ← DONE (see §4)
├── docs/
│   ├── plan.md        full technical plan: ERD + API reference
│   ├── kickoff.md     this file
│   └── team-notes.md  session log + conflict drill
├── profiles/          one page per member
├── info.txt           the submitted project proposal
├── CONTRIBUTING.md    Git/GitHub rulebook — read it
└── README.md
```

---

## 4. What's already built (initialization done)

The **backend is scaffolded and verified working.** Current state:

- ✅ Express REST API with all planned endpoints (auth, subjects, schedule, attendance,
  school works, dashboard).
- ✅ SQLite schema for 5 tables, created automatically on first run.
- ✅ JWT authentication with hashed passwords; every row is scoped to its owner.
- ✅ Input validation (zod) and a consistent JSON error shape.
- ✅ Demo seed data and an end-to-end smoke test — **25/25 checks passing**.
- ✅ **Flutter client scaffolded** (`client/`) for Android, iOS, Web, Windows, macOS:
  auth, dashboard, schedule, attendance, works, and subjects screens, wired to the API.
  `flutter analyze` is clean, unit tests pass, and the web build succeeds.
- ⏳ **Android tooling** (Android Studio + SDK) is not installed yet — that's next, so we
  can build the mobile target.

### API endpoints (already live)

Base URL `http://localhost:3000/api`. Everything except register/login needs
`Authorization: Bearer <token>`.

```
GET    /health
POST   /auth/register        POST /auth/login        GET /auth/me

GET    /subjects             POST /subjects
GET    /subjects/:id         PUT  /subjects/:id      DELETE /subjects/:id

GET    /schedule?day=        POST /schedule
PUT    /schedule/:id         DELETE /schedule/:id

GET    /attendance           POST /attendance
PUT    /attendance/:id       DELETE /attendance/:id
GET    /attendance/summary

GET    /works?status=&subjectId=&dueBefore=          POST /works
GET    /works/:id            PUT /works/:id          DELETE /works/:id
PATCH  /works/:id/status

GET    /dashboard/today
```

Full field-level detail is in [`plan.md`](plan.md) §5 and [`../server/README.md`](../server/README.md).

---

## 5. Get it running (5 minutes)

Prerequisites: **Node.js 22+**, **Git**. (Flutter comes later.)

```bash
# 1. clone
git clone https://github.com/NickBayer1026/PowerPuffBoys.git
cd PowerPuffBoys

# 2. install backend deps
cd server
npm install

# 3. local config
copy .env.example .env        # Windows  (macOS/Linux: cp .env.example .env)
#   …set JWT_SECRET to any long random string…

# 4. demo data (creates a login you can use right away)
npm run seed

# 5. run the API
npm run dev                   # http://localhost:3000
```

Open `http://localhost:3000/api/health` — you should see `{"status":"ok",...}`.

**Demo login** (from `npm run seed`):

```
email:    demo@classmate.app
password: demo12345
```

**Prove it works:** in another terminal, `cd server && npm run smoke` → all checks pass.

### Then the Flutter client

```bash
cd ../client
flutter pub get
flutter run -d edge        # opens the app in Edge, pointing at the local API
```

Full client notes (platform targets, Windows caveats): [`../client/README.md`](../client/README.md).

---

## 6. How we work (non-negotiable)

The full rulebook is [`CONTRIBUTING.md`](../CONTRIBUTING.md). The short version:

1. **Never commit to `main`** — it's protected. Everything goes through a branch + PR.
2. **One branch per task**, named `feature/short-description`.
3. **Never merge your own PR** — a teammate reviews and approves it.
4. **Commit messages:** `type: description` (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`).
5. **Never commit secrets.** `.env` and the SQLite database are gitignored — keep it that way.

The daily loop:

```bash
git checkout main && git pull origin main        # sync FIRST
git checkout -b feature/my-task                  # branch
#   ...work...
git add .
git commit -m "feat: describe what you did"
git push -u origin feature/my-task               # then open a PR
```

---

## 7. Who does what

| Area | Owner |
|---|---|
| Project management, repo/PR reviews, API design | Nick |
| Backend APIs (auth, subjects, schedule, attendance, works, dashboard) | Nick |
| Database schema, seed data, data integrity | Jetlee |
| Flutter client — screens, state, API integration | Jetlee + Clark |
| UI/UX — wireframes, theme, usability | Eulos |
| QA — test plan, cross-platform testing, bug reports | Raymart |
| Shared | Attendance-summary logic; end-to-end testing on all platforms |

> Five-person split: Nick runs the project and owns the API; Jetlee owns the database and
> pairs on the client; Clark is a third developer; Eulos owns UI/UX; Raymart owns QA.
> Attendance logic is paired because it spans client and server.

---

## 8. The plan (4 weeks)

| Week | Dates | Focus | Milestone |
|---|---|---|---|
| 1 | Oct 12–18 | Server scaffold; DB schema; auth | ✅ **Done** — API runs, register/login works |
| 2 | Oct 19–25 | Core REST APIs; Flutter scaffold; auth + subjects UI | Full API + login from the app |
| 3 | Oct 26–Nov 1 | Schedule, attendance, works UI; dashboard | All screens usable on Android |
| 4 | Nov 2–8 | Reminders; verify Android + Web + Windows; polish; demo | Demo-ready |

**Demo day:** Nov 9, 2026.

### Scope discipline — the MVP line

**Must ship:** auth, subjects, schedule (day + week), attendance marking + %, school
works, dashboard.
**Stretch:** reminders, reports/export, dark mode.
**Cut / future work:** QR check-in, multi-user class sharing, image uploads, cloud push,
offline sync, chat.

If we fall behind, stretch features are dropped first — the core app still demos.

### Platform honesty (put this in the demo)
On our Windows machine we can build and verify **Android, Web, and Windows desktop**.
**iOS/macOS builds require a Mac** — they're supported targets but code-complete only.

---

## 9. Start-here checklist

- [ ] Read this file and [`CONTRIBUTING.md`](../CONTRIBUTING.md).
- [ ] Confirm `node -v` is **22 or newer**.
- [ ] Get the backend running locally (§5) and hit `/api/health`.
- [ ] Run `npm run smoke` and see all checks pass.
- [ ] Add your profile page in [`profiles/`](../profiles/README.md) via your own branch + PR.
- [ ] Pick up your first task in §7 and open a branch.

---

## 10. Links

| Doc | What's in it |
|---|---|
| [`info.txt`](../info.txt) | The submitted project proposal |
| [`docs/plan.md`](plan.md) | Technical plan — architecture, ERD, full API reference, risks |
| [`server/README.md`](../server/README.md) | Backend setup, scripts, endpoint details |
| [`CONTRIBUTING.md`](../CONTRIBUTING.md) | Branch/commit/PR rules + troubleshooting |
| [`docs/team-notes.md`](team-notes.md) | Session log + the merge-conflict drill |
| [`profiles/`](../profiles/README.md) | Member profile exercise |
