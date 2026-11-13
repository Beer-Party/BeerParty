# 2026-11-13: S5, stop keeping last-known locations

- Found while reading the code: turning location sharing off never cleared the
  stored position either. `clearMemberLocation` sent an upsert built from a struct
  with optional `lat`/`lng`; nil values are left out of the JSON body, and a column
  that is left out keeps its old value. Only `updated_at` changed.
- `clearMemberLocation` is now an UPDATE that sends `lat` and `lng` as explicit JSON
  nulls. Being an UPDATE, it also cannot re-create a `member_state` row after the
  user has left the lobby.
- `LobbyView` now clears the user's stored position when the lobby view goes away
  (back, leave, delete) and when a closed lobby's 5-hour tail ends. A failed clear
  is retried on the next 20-second tick while the view is open. A location update
  that arrives after sharing has ended is dropped instead of written.
- New migration `20261113110000_clear_stale_member_locations.sql`: a function that
  nulls `lat`/`lng` on rows not written for an hour, for phones that never get to
  send the clear (switched off, app killed, no signal). The app already hides
  positions older than five minutes, so nothing visible changes. Execute is revoked
  from `anon` and `authenticated`.
- Verified: migration run twice in a throwaway local Postgres 16 with a stub
  `member_state` table (nothing touched the live project): the 2-hour-old position
  was cleared, the 10-minute-old one kept, `bac_estimate` untouched, client roles
  cannot execute it. Column names checked against the live schema (read-only).
  Two unit tests cover the request body. Swift build and tests: CI.
- Owner action after merge: run the migration in the Supabase SQL editor. The
  function does nothing until it is scheduled: pg_cron is not installed on the
  project, so also run the commented block at the bottom of the file once.
- Human check on a device: see the PR description.
- Not done here: positions written by an older app build are only removed by the
  server-side expiry.
