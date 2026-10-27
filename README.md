# PowerPuffBoys
This is a solid work of Group 7: Mobile App

> **New here? Read [`docs/kickoff.md`](docs/kickoff.md) first** — it's the project brief
> and the setup guide in one file.

---

## Team

| Member | GitHub | Role |
|---|---|---|
| NickBayer1026 | [@NickBayer1026](https://github.com/NickBayer1026) | Project Manager · Developer (repo owner) |
| Uttoh18 | [@Uttoh18](https://github.com/Uttoh18) | Developer · Database |
| RaymartCalasang | [@RaymartCalasang](https://github.com/RaymartCalasang) | Quality Assurance |
| eulosbustamante | [@eulosbustamante](https://github.com/eulosbustamante) | UI/UX Design |
| clarkcadiente24-rgb | [@clarkcadiente24-rgb](https://github.com/clarkcadiente24-rgb) | Developer |

## How we work

This is a team repo, so `main` is **protected**: nobody pushes to it directly. Everything
goes through a branch and a reviewed Pull Request.

```bash
git checkout main && git pull origin main        # sync first
git checkout -b feature/my-task                  # branch
#   ...edit files...
git add .                                        # stage
git commit -m "feat: describe what you did"      # commit
git push -u origin feature/my-task               # push
#   ...open a PR, get 1 approval, merge on GitHub...
git checkout main && git pull origin main        # sync after
```

**Read [CONTRIBUTING.md](CONTRIBUTING.md) before your first commit.** It has the full
branch naming rules, commit message format, review expectations, and a troubleshooting
table for when something goes wrong.

## Repository layout

```
PowerPuffBoys/
├── CONTRIBUTING.md          team rulebook — read this first
├── README.md                you are here
├── .github/
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/
│   ├── kickoff.md           START HERE — brief + setup guide
│   ├── plan.md              technical plan (ERD + API reference)
│   └── team-notes.md        shared scratchpad + conflict drill
├── server/                  Node + Express REST API (scaffolded + tested)
├── client/                  Flutter app (all platforms, wired to the API)
└── profiles/                one page per team member
```

## Current status

Repo scaffolding, the **backend**, and the **Flutter client** are all in place. The
Node + Express REST API is verified (`npm run smoke` → 25/25 checks passing) with SQLite
persistence and JWT auth, and the Flutter client (`client/`) is wired to it with login,
dashboard, schedule, attendance, school-works, and subjects screens (verified on Web).
See [`docs/kickoff.md`](docs/kickoff.md) to get set up.
