# Member Profiles

Each team member adds **one file** here: `profiles/<your-github-username>.md`

Because everyone creates a *different* file, no two pull requests will ever conflict.
This is deliberate — the goal of round 1 is to learn the branch → commit → push → PR →
review → merge loop, not to fight over merge conflicts. (We do that on purpose in
[`docs/team-notes.md`](../docs/team-notes.md).)

## Instructions

```bash
# 1. sync
git checkout main
git pull origin main

# 2. branch named after you
git checkout -b profile/<your-github-username>
```

Create `profiles/<your-github-username>.md` using the template below, then:

```bash
git add profiles/<your-github-username>.md
git commit -m "docs: add profile page for <your-github-username>"
git push -u origin profile/<your-github-username>
```

Open a Pull Request to `main`, fill in the template, and ask a teammate to review it.

## Template

```markdown
# <Full Name>

**GitHub:** [@<username>](https://github.com/<username>)

**Role on the team:** <e.g. Front-end, Backend, UI/UX, Documentation, QA>

**What I'm working on:** <one sentence>

**One Git command I've learned so far:**
`<command>` — <what it does, in your own words>
```

## Members

| Member | Profile |
|---|---|
| NickBayer1026 | [nickbayer1026.md](nickbayer1026.md) |
| Uttoh18 | [Uttoh18.md](Uttoh18.md) |
| RaymartCalasang | [RaymartCalasang.md](RaymartCalasang.md) |
| eulosbustamante | [eulosbustamante.md](eulosbustamante.md) |
| clarkcadiente24-rgb | [clarkcadiente24-rgb.md](clarkcadiente24-rgb.md) |
