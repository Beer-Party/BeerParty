# 2026-11-18: Q2 part 2, reading system-event rows moves out of `LobbyView`

- Second step of splitting `LobbyView.swift`. "Made it home", "lobby closed" and
  "motion due" arrive as rows in `drinks` with a magic name prefix. The four
  private methods that recognise and read those rows (`isSystemEvent`,
  `madeItHomeNickname`, `closedAtTime`, `motionArrivalTarget`) are now static
  functions on `LobbySystemEvent` in
  `BeerParty/Features/Lobby/LobbySystemEvent.swift`, with no UI.
- The logic is copied as it was; no behaviour change is intended. That includes
  one oddity the tests now pin down: a "motion due" row without the "|" separator
  is not treated as an event and would be shown as a drink.
- `LobbyView` keeps four one-line methods with the old names that call the new
  type, so none of the places that use them changed. This is on purpose: today's
  B7 pull request adds a call to `isSystemEvent`, and the two can be merged in
  either order. A later part can remove the one-liners.
- `LobbyView.swift` goes from 1,817 to 1,797 lines.
- This also prepares B5 step 3: when events move to the `lobby_events` table, the
  old-row reading is in one tested place.
- Unit tests in `LobbySystemEventTests`: an ordinary drink, each of the three
  events, the fallbacks (empty nickname, missing or unreadable close time, empty
  target).
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, with two phones in one lobby: tap "Made it home" on one; within 30
  seconds the other shows "<name> is safely at the fortress of dreams." and no
  extra drink appears in the graph. Close the lobby on the creator's phone; the
  other shows "Lobby closed. ..." within 30 seconds.
- Next parts of Q2, one per run: the drink form and the drink history as their own
  views (after today's B6 and B9 pull requests are merged, since they edit the
  same form), then the motions section.
