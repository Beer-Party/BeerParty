# 2026-11-19: U8, the Lock Screen dialogs use plain sentences

- The quick-add and vote buttons on the Lock Screen answered with developer text
  ("No active lobby found. Verify App Group is enabled on app and widget.") and
  with the server's raw reply ("Could not add drink. Supabase 401: {...}"). After
  the saved sign-in expires on a locked phone (B4), that 401 text is what the user
  saw.
- The dialogs now say:
  - no lobby context: "No lobby is active. Open a lobby in BeerParty first."
  - sign-in expired (status 401): "Couldn't add the drink. Open BeerParty, then
    try again."
  - offline or timed out: "Couldn't add the drink. You seem to be offline."
  - anything else: "Couldn't add the drink. Please try again."
  The vote button uses the same sentences with "send your vote".
- The mapping is `QuickAddFailure` in the file shared by app and widget
  (`LockScreenQuickAdd.swift`), so the tests can reach it. The status code and the
  server's reply are no longer read into any text.
- The success texts ("Added Beer.", "Aye vote submitted.") and "Custom drink
  unavailable." / "No active motion to vote on." are unchanged.
- Unit tests in `QuickAddFailureTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: (1) with the Live Activity on the Lock Screen, turn on flight mode
  and tap Beer: "Couldn't add the drink. You seem to be offline." (2) Back online,
  tap Beer: "Added Beer." as before. (3) If convenient, leave the phone locked for
  over an hour and tap Beer: "Couldn't add the drink. Open BeerParty, then try
  again."
- This pull request and the B11 one (closed lobby) both edit
  `BeerPartyWidget/AppIntent.swift`, at different lines; they merge in either
  order.
- Backlog: U8 is one of the items proposed in pull request #27, which is not
  merged yet, so there is no line on `main` to tick and `BACKLOG.md` is not
  changed here (adding the line would conflict with #27). Once #27 is merged, a
  later run ticks U8.
