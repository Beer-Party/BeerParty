# 2026-11-25: U12, "Made it home" keeps working after closing time

- Before: the "Made it home" button was disabled as soon as the lobby was
  closed, and `sendMadeItHome` refused as well. The host normally taps
  "Closing Time" when the group leaves the bar, just before people walk home,
  so the button was gone exactly when it was needed. The other phones would
  still have shown the message: they keep reading new rows for 5 hours after
  closing.
- Now: "Made it home" can be sent while the lobby is open and for 5 hours
  after the lobby's closing time, the same 5 hours the lobby screens keep
  their live updates. The rule is one tested function,
  `MadeItHomeWindow.canSend`, used by the button, by the screen before sending
  and by `LobbyBackendService.sendMadeItHome`. `shouldContinueLiveUpdates`
  now uses the same constant, so the two cannot drift apart.
- The closing time is the one the lobby screen already knows (from the
  closing note, or the moment this phone closed the lobby). A lobby closed by
  the 24-hour auto-close has no closing note, so there the button stays off as
  before; the other phones have no live updates there either.
- Migration file, not applied:
  `supabase/migrations/20261125110000_allow_made_it_home_after_closing.sql`
  replaces the insert policy of `lobby_events` (B5 step 1) so a
  `made_it_home` row is also allowed within 5 hours of the lobby's
  `lobby_closed` event. The other two kinds keep their rules unchanged. It
  must run after `20261115110000_create_lobby_events.sql`; B5 step 2 now says
  so. Nothing changes for users until the app uses `lobby_events` (B5 step 3).
- Today the message is still a row in `drinks`. Whether the database lets a
  member add a row to a closed lobby is not in the repo (S1). The host's
  closing note is added the same way after the lobby is closed, so it most
  likely works; if not, the member sees "Couldn't send your made-it-home
  update" as before.
- Tests: `MadeItHomeWindowTests` (open lobby, just after closing, after 5
  hours, a closing time slightly ahead of this phone's clock, no closing
  time).
- Verified: build and unit tests in CI. The SQL file was read, not run.
  Not tested on a device.
- Human check, two phones A (creator) and B:
  - A taps "Closing Time" twice. On B, "Made it home" is still enabled; tap
    it: B shows "... is safely at the fortress of dreams." and within about 30
    seconds A shows the same line.
  - A lobby closed more than 5 hours ago: the button is grey.
- Backlog: the U12 box is left unticked, because #53 (U11) changes the line
  right above it and ticking it here would make the two pull requests
  conflict. U12 says it is done; tick the box when merging. B5 step 2 names
  the new file.
