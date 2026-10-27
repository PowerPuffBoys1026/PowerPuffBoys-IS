## What this changes

Import the full project files from the local working copy into the repository on branch `feature/all-from-scratch`. This brings the complete codebase (client, server, docs, profiles, configs) in line with the current project state.

## Why

To sync the latest local changes to the remote repository so they can be reviewed and merged via Pull Request to `main`.

## Checklist

- [x] I branched off `main` and did **not** commit on `main`
- [x] I pulled `main` before starting, so this branch is up to date
- [x] I ran the app / tests and it works
- [ ] I removed debug statements and `console.log` left behind
- [x] I did not commit any secrets, `.env` files, or API keys
- [x] My commit messages follow `type: description`
- [ ] I asked a teammate to review this

## How to test

1. Checkout the branch: `git checkout feature/all-from-scratch`
2. Review the files in `client/` and `server/`
3. Follow setup instructions in `README.md` / `docs/kickoff.md` to run the app

## Screenshots

<!-- If the change is visual, add before/after screenshots here. -->
