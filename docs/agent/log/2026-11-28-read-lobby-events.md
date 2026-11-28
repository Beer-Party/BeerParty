# 2026-11-28: B5 step 3b, the app reads `lobby_events`

- Background: "made it home", "lobby closed" and "motion due" are rows in
  `drinks` with magic name prefixes. Since step 3a the app also writes each
  of them to the table `lobby_events`. This step reads that table, and goes
  on reading the prefixed rows, because phones on older versions write only
  those.
- New, `LobbyEventFeed` (no UI, no network): makes one list out of the two
  sources. This version writes every event twice, so the same event must be
  announced once. The rule:
  - a row that was read before is skipped;
  - a prefixed row and an event are the same thing when they are of the same
    kind and: "lobby closed", always; "motion due", for the same motion;
    "made it home", from the same member and at most ten minutes apart (the
    row has the phone's clock, the event the server's);
  - each row has one twin at most, the nearest in time, so two real "made it
    home" taps by one member stay two.
  The two halves may arrive in the same poll or in different ones, in either
  order.
- `LobbyBackendService.fetchLobbyEvents` (in a file of its own) reads the
  lobby's events, after a time when one is given. A kind this version does
  not know is skipped.
- `LobbyView`:
  - When the lobby is loaded, the events are read as well, and the closing
    time comes from the merged list.
  - The 30-second poll asks for events newer than the newest one it has and
    announces what is new through the merged list. The sentences are the
    same as before. The nickname and the motion's destination now come from
    the members and motions loaded on the screen; the text inside a prefixed
    row (which any member could make up) is only used when that finds
    nothing.
  - A failed read of the events says nothing and changes nothing: the screen
    goes on with the prefixed rows alone. So this also works against a
    database without the table.
  - One request more per phone every 30 seconds while live updates run.
- Not changed: real drinks are told from system rows by the prefix, as
  before (`LobbySystemEvent.isSystemEvent`). That stays until step 4.
- The two gaps named in the log of step 3a:
  - The 24-hour auto-close writes neither a prefixed row nor an event. Left
    as it is: a lobby closed that way has no closing time on this screen, as
    before. It needs the database to write the event when it closes the
    lobby, which is a migration for a later step.
  - "Made it home" after closing, in a lobby whose host closed it with an
    older version: the table refuses the event, the prefixed row is written.
    Covered, because the prefixed rows are still read.
- Left over, small: three private helpers in `LobbyView` (`closedAtTime`,
  `motionArrivalTarget`, `madeItHomeNickname`) are no longer called, and the
  comment above `recordLobbyEvent` still says "nothing reads it yet". Both
  were left alone because other pull requests of today edit the lines next
  to them; step 4 removes them.
- Known edge: a phone whose clock is more than ten minutes off, sending
  "made it home", is announced twice on the other phones (once for the row,
  once for the event).
- Tests: `LobbyEventFeedTests` (reading both sources, the JSON of an event
  row, merging in one poll and across polls, the cursor, what is announced).
- Verified: build and unit tests in CI. The read itself was not run against
  the database.
- Human check on a device, two phones in one lobby, both on this version:
  - Phone A taps "Made it home": phone B shows "... is safely at the
    fortress of dreams." once, within half a minute, not twice.
  - A motion passes and comes due: "Motion time: Head towards ..." appears
    once on each phone, with the right destination.
  - The host taps "Closing Time": the other phone shows "Lobby closed. ..."
    once and its buttons switch off.
  - If one phone still has the version before 2026-11-27: its "Made it home"
    is still announced on the new one.
- Backlog: B5 step 3b ticked. Step 4 waits until this version is on the
  phones.
