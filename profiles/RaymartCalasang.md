# Raymart Q. Calasang

**GitHub:** [@RaymartCalasang](https://github.com/RaymartCalasang)

**Role on the team:** Quality Assurance (QA)

**What I'm working on:** Keeping ClassMate reliable across platforms — writing the test
plan, verifying the MVP (auth, subjects, schedule, attendance, school works, dashboard),
filing reproducible bug reports, and running the pre-merge QA checks so every PR is
tested before it lands. Shared with Nick: attendance-summary logic and end-to-end testing
on all platforms.

**One Git command I've learned so far:**
`git checkout -b profile/RaymartCalasang` — creates a new branch named after me and
switches to it, so my profile work stays off `main` and is ready to push as its own PR.

**QA checks I run before signing off a change:**
- Backend: `cd server && npm run smoke` — expect **25/25** checks passed.
- Client: `cd client && flutter analyze` (clean) + `flutter test` (green) + web build.
- Verify the changed screen/endpoint on the target platform(s).

**Notes for the team:**
- Test on **Android + Web (Edge) + Windows** by the **end of Week 3**, not Week 4.
- Attendance `%` = `present / (present + absent + late)`; **cancelled is ignored** and the
  value is **computed, never stored** — that formula is the single source of truth.
- Bugs are easiest to fix when they're short and reproducible (title, build, steps,
  expected, actual, evidence, severity).
- PR rules live in [CONTRIBUTING.md](../CONTRIBUTING.md); full QA brief in
  [my-role.md](../my-role.md).
