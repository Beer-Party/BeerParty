# 2026-11-27: B5 step 3a, the app also writes its events to `lobby_events`

- Background: "made it home", "lobby closed" and "motion due" are rows in
  `drinks` with magic name prefixes. The table `lobby_events` (applied by an
  owner on 2026-11-26) is their proper home. Step 3 of B5 was "the app writes
  and reads `lobby_events`"; this is the writing half, kept apart so each
  half is small enough to review.
- Now, in `LobbyBackendService`: `sendMadeItHome`, `closeLobby` and
  `notifyMotionArrivalIfNeeded` write the prefixed row exactly as before and
  then one row to `lobby_events` (`recordLobbyEvent`). Phones on older
  versions only understand the prefixed rows, so those stay until step 4.
- The second write is best effort and never fails the action or shows a
  message. The table's own rules refuse what they should: a second "closed"
  for a lobby, a second "due" for a motion, an event from a non-member.
- `LobbyEventRequest` is the new row: lobby, kind, and the motion for
  "motion due". It sends no user and no time (the database sets both) and
  can only be built in the three shapes the table accepts.
- Nothing reads the table yet, so nothing changes on screen. Step 3b reads
  it (and the old rows), and has rows to read from this version on.
- Known gaps, for step 3b to handle:
  - The 24-hour auto-close writes neither a prefixed row nor an event (as
    before).
  - "Made it home" after closing is only accepted by the table when the
    lobby's "closed" event is there, so not for a lobby closed by a host on
    an older app version. The prefixed row is still written in that case.
- Tests: `LobbyEventRequestTests` (the JSON that is sent, for each kind).
- Verified: build and unit tests in CI. The insert itself was not run
  against the database.
- Human check, after an evening with this version (or a quick try with two
  accounts): in the Supabase table editor, `lobby_events` has one row per
  "Made it home" tap, one `lobby_closed` row per closed lobby and one
  `motion_due` row per passed motion. In the app everything looks as before.
- Backlog: B5 step 3 split into 3a (ticked) and 3b.
