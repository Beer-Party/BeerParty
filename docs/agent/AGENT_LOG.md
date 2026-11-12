# Agent log

Newest first. One entry per run: date, what was done, PR, anything a human must do.

## 2026-11-11: setup

- Read the whole codebase and wrote `BACKLOG.md`.
- Added CI (`.github/workflows/ci.yml`): builds the app and runs unit tests on a
  macOS runner for every PR. Added a shared `BeerParty` scheme so CI can find it.
- Not verified yet: the CI workflow has never run. First run may need a fix.
- Could not read the database: the Supabase project is paused.
