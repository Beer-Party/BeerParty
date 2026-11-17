# 2026-11-17: Q4, the BAC simulation no longer runs on every render

- `LobbyView.body` built a full BAC snapshot (a simulation in 10-minute steps for
  every member, over every drink) each time it rendered. Typing one character in
  the drink form re-renders the screen, so each keystroke re-ran the simulation.
- New `BACSnapshotCache` keeps the last snapshot and the inputs it was built from
  (members, drinks, body parameters, timestamp). `body` asks the cache; when the
  inputs are the same as last time it returns the stored snapshot.
- The simulation still runs whenever something that affects the result changes:
  a drink is added, edited or deleted, a member joins or leaves, body parameters
  load, or the 30-second timer moves the clock on.
- `LobbyMemberData`, `LobbyDrink` and `LobbyBACParamsData` are now `Equatable` so
  the inputs can be compared. No behaviour change from that.
- The 5-minute BAC sync to the server still calls the calculator directly; it uses
  its own timestamp and would only push the screen's snapshot out of the cache.
- Unit tests in `BACSnapshotCacheTests`: same inputs simulate once, the cached
  result equals the calculator's, and a new drink, a later time, a new member or
  new body parameters each cause a fresh simulation.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: in a lobby with a few members and drinks, type in the "Drink name"
  field: typing feels at least as smooth as before. Add a drink: the Live BAC list
  and the graph update at once. Wait a minute: the values still tick down on the
  30-second timer.
