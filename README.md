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
├── client/                  Flutter app (Android, iOS, Windows, macOS)
└── profiles/                one page per team member
```

## Current status

The Node + Express server provides the browser app at `http://localhost:3000/` and the
REST API at `/api`. Flutter remains the Android, iOS, Windows, and macOS client; its
legacy Web target has been removed so the redesigned browser app is the only website.
See [`server/README.md`](server/README.md) to launch the site and
[`docs/kickoff.md`](docs/kickoff.md) for project setup.
