# Git Cheat Sheet for PowerPuffBoys

Use this when you want to work without asking for help every time.

## 1) One-time setup

```bash
git config --global user.name "Your Full Name"
git config --global user.email "you@example.com"
```

Check your GitHub email here:

- https://github.com/settings/emails

## 2) Start each task from main

```bash
git checkout main
git pull origin main
```

## 3) Create a feature branch

```bash
git checkout -b feature/my-task
```

Examples:

```bash
git checkout -b feature/login-fix
git checkout -b fix/dashboard-bug
git checkout -b docs/update-readme
```

## 4) Make changes, then check status

```bash
git status
```

## 5) Stage and commit

```bash
git add .
git commit -m "feat: describe your change"
```

Common prefixes:

- `feat:` new feature
- `fix:` bug fix
- `docs:` docs update
- `refactor:` code cleanup
- `test:` tests
- `chore:` project maintenance

## 6) Push to GitHub

```bash
git push -u origin feature/my-task
```

After the first push:

```bash
git push
```

## 7) Open a Pull Request

- Go to GitHub
- Open your branch
- Click Compare & pull request
- Get review and merge after approval

## 8) After merge

```bash
git checkout main
git pull origin main
```

Optional cleanup:

```bash
git branch -d feature/my-task
```

## Quick workflow

```bash
git checkout main && git pull origin main && git checkout -b feature/my-task
# make changes

git add . && git commit -m "feat: describe your change" && git push -u origin "$(git branch --show-current)"
```

## Important rules

- Never push directly to `main`
- Always use a feature branch
- Open a PR before merging
- Do not commit to protected `main`

## Helpful commands

```bash
git remote -v
git status --short --branch
git restore .
git pull --rebase origin feature/my-task
git commit --amend -m "correct message"
```

This project follows the branch and commit rules in [CONTRIBUTING.md](CONTRIBUTING.md).
