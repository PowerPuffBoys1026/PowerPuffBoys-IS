# My Role — Jetlee L. Uttoh (@Uttoh18)

> Personal reference. Group 7 (PowerPuffBoys) · ClassMate · Started 2026-10-12 ·
> Demo 2026-11-09.

## Who I am on the team

| Field | Value |
|---|---|
| Name | Jetlee L. Uttoh |
| GitHub | [@Uttoh18](https://github.com/Uttoh18) |
| Role (docs) | Developer · Database |
| Role (profile) | Backend Developer |
| Pairs with | Clark (Flutter client) |

## What I own

Per `docs/kickoff.md` §7 and `docs/plan.md` §8:

- **Database schema, seed data, data integrity** — primary responsibility.
- **Flutter client — screens, state, API integration** — paired with Clark.
- **Shared:** attendance-summary logic + end-to-end testing on all platforms.

## Where my work lives

```
server/src/
├── db.js         SQLite connection + schema   ← my main area
├── seed.js       demo data                    ← my main area
├── config.js     env-driven config
├── middleware/   auth (JWT), error handling
├── services/     attendance summary logic     ← shared (paired)
├── utils/        validate (zod), HttpError
└── routes/       auth, subjects, schedule, attendance, works, dashboard

client/lib/       Flutter app                 ← shared with Clark
├── api/ models/ screens/ state/ utils/
```

## Data model I maintain (ERD summary)

5 tables, every row scoped to its owner `user_id` via the JWT:

| Table | Key fields |
|---|---|
| `users` | id, email, password_hash, full_name, student_no, course, created_at |
| `subjects` | id, user_id FK, code, title, instructor, units, color, created_at |
| `schedule_slots` | id, subject_id FK, day_of_week, start_time, end_time, room, modality |
| `attendance_records` | id, subject_id FK, slot_id FK, date, status, note, created_at |
| `school_works` | id, user_id FK, subject_id FK (nullable), title, type, due_at, priority, status, notes, created_at, updated_at |

**Rules I protect:**
- `attendance_records.status` ∈ `present | absent | late | cancelled`.
- `school_works.type` ∈ `assignment | quiz | exam | project`;
  `priority` ∈ `low | medium | high`; `status` ∈ `todo | doing | done`.
- **Attendance % is computed, never stored** — `present / (present + absent + late)`;
  `cancelled` is ignored. Keeps the number honest if records are edited.
- Threshold defaults to 20% (`ATTENDANCE_THRESHOLD` in `.env`).
- Dates `YYYY-MM-DD`, times `HH:MM` (24h), timestamps ISO-8601.

## How I work here (the 4 rules)

1. Never commit to `main` — it's protected.
2. One branch per task: `feature/short-description`.
3. Never merge my own PR — a teammate approves.
4. Commits: `type: description` (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`).

```bash
# daily loop
git checkout main && git pull origin main     # sync FIRST
git checkout -b feature/my-task               # branch
# ...work...
git add .
git commit -m "feat: describe what I did"
git push -u origin feature/my-task            # then open a PR
```

Never commit secrets — `.env` and the SQLite DB are gitignored.

## My next tasks

- [ ] Get the backend running locally and confirm `npm run smoke` → 25/25.
- [ ] Review and own `server/src/db.js` + `server/src/seed.js`.
- [ ] Pair with Clark on Flutter client screens/state/API integration.
- [ ] Pair on the shared attendance-summary logic (`server/src/services/`).
- [ ] End-to-end verification on Android + Web + Windows.

## Links

- Brief + setup: [`docs/kickoff.md`](docs/kickoff.md)
- Technical plan (ERD + API): [`docs/plan.md`](docs/plan.md)
- Git rulebook: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- My profile: [`profiles/Uttoh18.md`](profiles/Uttoh18.md)
