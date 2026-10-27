# Contributing to PowerPuffBoys

Group 7 - Mobile App. This document is the rulebook. If something here disagrees with
what you remember, this document wins.

## Team

| Member | GitHub | Role |
|---|---|---|
| NickBayer1026 | [@NickBayer1026](https://github.com/NickBayer1026) | Project Manager · Developer — repo owner / final merge approval |
| Uttoh18 | [@Uttoh18](https://github.com/Uttoh18) | Developer · Database |
| RaymartCalasang | [@RaymartCalasang](https://github.com/RaymartCalasang) | Quality Assurance |
| eulosbustamante | [@eulosbustamante](https://github.com/eulosbustamante) | UI/UX Design |
| clarkcadiente24-rgb | [@clarkcadiente24-rgb](https://github.com/clarkcadiente24-rgb) | Developer |

## The 4 rules

1. **Never commit directly to `main`.** `main` is protected, GitHub will block the push.
2. **One branch per task.** Branch name describes the task.
3. **Never merge your own PR.** Someone else reviews and approves it.
4. **Always follow rule 1.** 

## Setup (one time per machine)

Make sure your Git email matches an email registered on your GitHub account, or your
commits will not be attributed to you:

```bash
git config --global user.name "Your Full Name"
git config --global user.email "you@example.com"
```

Check it at [github.com/settings/emails](https://github.com/settings/emails).

Then clone:

```bash
cd <your project folder>
git clone https://github.com/NickBayer1026/PowerPuffBoys.git
cd PowerPuffBoys
```

## The daily loop

```bash
# 1. sync — do this FIRST, every single time
git checkout main
git pull origin main

# 2. branch — one per task, never reuse an old branch
git checkout -b feature/my-task

#    ...create / edit / delete files...

# 3. stage
git status                 # check what you actually changed
git add .                  # or: git add path/to/file.ext

# 4. commit
git commit -m "feat: add profile page"

# 5. push — only the first time on a branch
git push -u origin feature/my-task

#    ...open a Pull Request on GitHub, get it reviewed, wait for merge...

# 6. sync — do this AFTER your PR is merged
git checkout main
git pull origin main

# 7. clean up the finished branch
git branch -d feature/my-task
```

## Branch naming

| Prefix | Use for |
|---|---|
| `feature/` | new functionality |
| `fix/` | bug fix |
| `docs/` | documentation only |
| `refactor/` | restructuring, no behaviour change |
| `profile/` | the practice exercise in `profiles/` |

Format: `prefix/short-description-in-lowercase`
Good: `fix/login-crash-on-empty-input`  Bad: `Fix Stuff`, `johns-branch`

## Commit message format

```
type: short description in the imperative
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

```
feat: add member profile page
fix: prevent duplicate submit on login
docs: add setup instructions to README
```

**Good:** explains *what* changed and is under ~50 characters after the type.
**Bad:** `stuff`, `asdfgh`, `fixed it again`, `changes` (no type, no clarity).

## Pull request rules

- Branch must be up to date with `main` before merging.
- At least **1 approval** required — from a teammate, not yourself.
- Fill in the whole PR template.
- Review someone else's PR at least once per week. Read the diff
  ("Files changed" → click a file → green/red), not just the description.

## Resolving a merge conflict

Conflicts only happen when two people change the same lines of the same file.

```bash
git pull origin main        # conflict appears
git status                  # lists "both modified" files
```

Open the conflicted file. You'll see markers:

```
<<<<<<< HEAD
our version
=======
their version
>>>>>>> origin/main
```

Delete the markers, keep the correct content, then:

```bash
git add path/to/conflicted/file
git commit -m "docs: resolve merge conflict in team notes"
git push
```

## Troubleshooting

| Problem | Fix |
|---|---|
| Push rejected: "fetch first" | `git pull --rebase origin <branch>` then `git push` |
| Committed straight to `main` | `git branch backup` → `git reset --hard origin/main` → redo on a branch |
| Accidentally deleted a tracked file | `git restore <file>` |
| Wrong commit message | `git commit --amend -m "correct message"` |
| Want to throw away uncommitted changes | `git restore .` |
| Want to see who changed what | GitHub → **Insights → Network** |
| Wrong remote | `git remote -v` |
| Reset to the very beginning | `git reset --hard origin/main` (destroys local commits) |
