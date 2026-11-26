# 2026-11-26: B24, timed and automatic failures no longer put an error on the screen

- Before: when the five-minute background BAC write failed,
  `syncCurrentUserBACIfNeeded` wrote "Couldn't update your BAC for the lobby
  ..." into the status line, and again every five minutes while the phone had
  no signal. `handleOwnLocationUpdate` did the same with "Couldn't share your
  location" for every new position while walking without signal. Both
  replaced the line about what the user had just done, and since the status
  banner (#51) they popped up at the bottom of the screen again and again.
- Now, in `LobbyView`:
  - The BAC write reports a failure only when it follows the user's own
    action (a drink added, changed or deleted, the lobby opened or pulled to
    refresh; these calls pass `force: true`). The five-minute timer's write
    fails silently and is tried again five minutes later, as before.
  - The location upload reports a failure only for the first upload after
    sharing was switched on (also when the lobby screen opens with sharing
    already on, because that goes through the same code). Later positions
    and the timed resend fail silently; the next position or the 20-second
    timer tries again.
- The rule is `LobbyWriteOrigin` (`userAction`, `timer`, `automatic`), a plain
  type with tests. Nothing about when or how often the writes happen changed,
  only whether a failure is shown.
- Not changed: the forced BAC write after "Added Beer." can still replace
  that line with "Couldn't update your BAC ..." when the drink was saved and
  the BAC write right after it failed. The backlog item asks to keep the
  message for user actions, so it stays; say so if you would rather have it
  silent too (the other phones work out everyone's BAC from the drinks, not
  from this value).
- Tests: `LobbyWriteOriginTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check:
  - Open a lobby with location sharing on, wait until your pin is on the
    map, then switch on flight mode and leave the screen open for six
    minutes (walking around if possible). No "Couldn't update your BAC" or
    "Couldn't share your location" banner appears.
  - Still in flight mode, tap a quick-add drink: "Couldn't add the drink
    ..." appears as before.
  - Flight mode off: within a minute the pin is fresh again and drinks can
    be added.
- Backlog: B24 ticked (checkbox only).
