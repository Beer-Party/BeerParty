# 2026-11-15: B5 step 1, a `lobby_events` table

- Added `supabase/migrations/20261115110000_create_lobby_events.sql`. It creates
  `lobby_events` for the three system events that are stored as fake drinks today
  ("made it home", "lobby closed", "motion due"). Migration file only: no Swift
  changed, nothing applied to the live project, and the app does not use the
  table yet.
- A row holds the lobby, the member, the kind, the motion (for "motion due") and
  a server-set time. There is no free text: the app can show the nickname from
  `lobby_members` and the motion text from `motions`, so a member has nothing to
  forge.
- Rules: members read their lobby's events. A member adds "made it home" only for
  themselves and only while the lobby is open; only the creator adds "lobby
  closed", only after closing, once per lobby; "motion due" needs a passed motion
  of the same lobby, once per motion. No updates or deletes; rows go when the
  lobby is deleted.
- Verified in a throwaway local Postgres 16 with stub `lobbies`, `lobby_members`,
  `motions`, `auth.users` and `auth.uid()`: the file runs twice without error,
  and 16 cases behave as listed above (allowed inserts succeed with the server's
  time even when the client sends another; forged, cross-lobby, duplicate,
  wrong-kind, update, delete and signed-out attempts are refused; a member of
  another lobby sees nothing; deleting the lobby removes its events). Column
  names (`lobbies.created_by`, `lobbies.is_active`, `lobby_members.user_id`,
  `motions.passed`) were taken from the Swift code and `supabase_motions.sql`,
  not from the live database.
- Human action: an owner runs the file in the Supabase SQL editor, then ticks
  step 2 under B5 in `BACKLOG.md`. Nothing to check on a device.
- For step 3: a second "motion due" or "lobby closed" insert fails with a
  unique-violation (HTTP 409). The client should treat that as "already
  recorded", not as an error. The events are read with one extra query per
  refresh until Q8 (Realtime).
