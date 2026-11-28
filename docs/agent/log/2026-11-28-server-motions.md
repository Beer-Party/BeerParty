# 2026-11-28: S4 step 1, the database decides a motion, not the phone

- Why: until now the phone that polled first after voting ended worked out
  "passed" from its own member list (which can be old) and its own clock, and
  wrote the result into `motions`. Two phones could disagree, and the first
  one won.
- What the database could already do (read from `supabase/schema.sql`):
  - The trigger `close_motion_when_all_members_voted` closes a motion at the
    moment the last member votes.
  - The function `close_expired_motions(p_lobby_id)` closes motions whose
    voting time is over (corrected by S3, applied by an owner on 2026-11-26).
    It only runs when someone calls it; nothing called it.
- Now: when a motion the phone just read looks due, the app calls
  `close_expired_motions` for its lobby and, if the database closed
  something, reads the motions again. The app no longer writes `status` or
  `passed`. `LobbyBackendService.closeMotion` is replaced by
  `closeExpiredMotions`; `MotionServerClosing` holds the two decisions
  ("ask the server?", "read again?"). No migration was needed.
- The rule is the same on both sides: passed means more than two thirds of
  all lobby members voted aye; a tie or no votes fails; members who did not
  vote count against; a lobby with no members counts as one. Differences:
  - The database counts the members itself at that moment. The phone's list
    could be up to two minutes old. This is the point of the change.
  - The database uses its own clock. A phone whose clock is ahead asks a
    little early, gets "nothing closed" and asks again at the next refresh
    (30 seconds).
  - If a phone's member list is too short it can think "everyone voted"
    while the database is still waiting for someone. It then asks every 30
    seconds until voting ends (one small request each, no second fetch).
    Before, that phone would have closed the motion too early.
- Decisions:
  - If the call fails (no signal), nothing is shown and the next refresh
    tries again. It is a timed background action (as in B24).
  - The motions are fetched a second time only when the database says it
    closed at least one (Q9 kept). If another phone closed it a moment
    earlier, this phone sees the result at its next refresh.
  - `MotionTally.closings` and its tests stay: the phone's own count is now
    the reason to ask, not the result. `MotionResolveUpdateRequest` in
    `Lobby.swift` is no longer used and is left in place to keep this diff
    small; step 2 can remove it.
  - Phones on older versions still write results themselves, with the same
    rule. That ends with step 2.
- Found for step 2: taking away the members' right to update `motions` would
  also stop the trigger (it runs as the voter) and the app's `notified_at`
  write. Both have to move into definer functions in the same migration.
  Written into the backlog item.
- Not changed: creating a motion, voting, the "Motion time: ..." message and
  the code that writes it.
- Tests: `MotionServerClosingTests`.
- Verified: build and unit tests in CI. The call itself was not run against
  the database; the function's SQL was read, not executed, in this run.
- Human check, two phones in one lobby:
  - Propose a motion "in 5 min", vote aye on one phone only, wait for the
    voting time to end: both phones show it under past motions as not
    passed, within about half a minute.
  - Propose another, vote aye on both: it closes at once as passed, and at
    its time both phones show "Motion time: Head towards ...".
  - In the Supabase table editor the closed rows in `motions` have `status`
    closed, `passed` and `resolved_at` filled.
- Backlog: S4 not ticked; step 1 ticked, step 2 described.
