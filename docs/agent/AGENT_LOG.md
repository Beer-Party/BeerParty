# Agent log

Newest first. One entry per run: date, what was done, PR, anything a human must do.

Entries from 2026-11-13 on live in `log/`, one file per PR. This file is history.

## 2026-11-12: S3, expired-motion tally

- Fixed `close_expired_motions`: ayes and members are now counted in separate
  subqueries, so one aye in a five-person lobby is 1/5, not 5/5. Shipped as
  `supabase/migrations/20261112110000_fix_close_expired_motions_tally.sql`, and the
  same change made in the reference copy `supabase_motions.sql`.
- Verified in a throwaway local Postgres 16 with stub tables (nothing touched the
  live project): old function passed 1/5, 3/5 and 2/3; new one passes only 4/5.
  Migration is safe to run twice.
- No Swift changed. The app does not call this function today (it tallies on the
  client, see S4), so this matters once the pg_cron job at the bottom of
  `supabase_motions.sql` is enabled or S4 lands.
- Owner action after merge: run the migration file in the Supabase SQL editor,
  then tick it in section 0 of `BACKLOG.md`.
- The Supabase project is no longer paused (status active on 2026-11-12). S1 is
  therefore unblocked: an owner can drop its `needs-owner` tag so a later run dumps
  the schema into `supabase/migrations/`. The backlog text for S1 still says paused.
- Noticed, not changed (belongs to S4): the function is `security definer` and
  callable by any signed-in user for any lobby, including with no lobby id.
- First CI runs (PR #1 and the merge to main) were green, so the setup note
  "CI has never run" is resolved.

## 2026-11-11: setup

- Read the whole codebase and wrote `BACKLOG.md`.
- Added CI (`.github/workflows/ci.yml`): builds the app and runs unit tests on a
  macOS runner for every PR. Added a shared `BeerParty` scheme so CI can find it.
- Not verified yet: the CI workflow has never run. First run may need a fix.
- Could not read the database: the Supabase project is paused.
