# 2026-11-18: B7, other members' edits, deletions and late drinks now arrive

- The 30-second refresh asks only for drinks stamped later than the newest one on
  screen. Another member's edit or deletion changes no such row, so it never
  arrived; neither did a drink from a phone whose clock is behind. Other phones
  kept the old drink in the BAC and graph until someone pulled to refresh.
- New: every two minutes the lobby screen reloads the whole drink list
  (`LobbyBackendService.fetchAllDrinks`, one request) and shows it if it differs.
  The 30-second refresh is unchanged and still brings new drinks quickly.
- The decisions are in `DrinkListReload`
  (`BeerParty/Features/Lobby/DrinkListReload.swift`), a plain type with tests:
  - `reloadedList` returns the new list, or nil when nothing differs. It also
    returns nil when the list on screen changed while the request was in flight
    (you added, edited or deleted a drink, or the 30-second refresh ran), because
    the server's answer may be older than that change. The next reload catches up.
  - `drinksNotShown` stops the 30-second refresh from adding a drink a second time
    when the full reload delivered it first. A drink added twice would count twice
    in the BAC.
- The reload is also skipped while one of your own add, edit or delete requests is
  still running.
- Cost: one extra request per phone every two minutes, returning all drinks of the
  lobby. This goes away with Q8 (Realtime).
- Not changed: the lobby-closed, made-it-home and motion messages still come from
  the 30-second refresh only.
- Unit tests in `DrinkListReloadTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, with two phones in one lobby: (1) on phone A add a drink, wait for
  it to show on phone B, then edit it on A (for example ABV 5 to 9): within about
  two minutes B's graph and BAC for that member change, without pull-to-refresh.
  (2) Delete that drink on A: within about two minutes it is gone from B's graph.
  (3) Add a few drinks on both phones in quick succession: no drink appears twice
  in "My Drinks Tonight" and the BAC does not jump.
