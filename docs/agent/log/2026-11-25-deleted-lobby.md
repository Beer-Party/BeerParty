# 2026-11-25: B20, a lobby the host deleted no longer stays open on other phones

- Before: when the creator tapped "Delete Lobby", the other members' lobby
  screens were not told. The 30-second check got "lobby not found" and ignored
  it as a passing failure, so the screen kept saying "Status: Active" and every
  "Add Drink" failed with "Lobby not found.". The Lock Screen buttons read the
  empty answer as "unknown", tried the drink anyway and said "Please try
  again." every time.
- App (`LobbyView`): "the lobby row is gone" (`LobbyLifecycleError.lobbyNotFound`,
  recognised by the new `LobbyLifecycleError.meansLobbyIsGone`) is now its own
  case on the 30-second check, on opening the lobby and when adding a drink.
  The screen then ends quick add and location sharing (which also clears this
  member's stored coordinates, best effort), shows "This lobby was deleted by
  its host." and goes back to the hub on "OK". A network failure is not "gone",
  so being offline still never throws anyone out.
- Not while this phone is itself deleting or leaving the lobby: that action
  closes the screen already.
- Widget (`QuickAddDrinkIntent`): `LobbyOpenState` has a new case `gone` for a
  successful answer with no lobby row. The intent then ends the Live Activity,
  removes the saved quick-add context (it holds the sign-in token, and nothing
  can be added to that lobby again) and says "This lobby was deleted by its
  host.". A failed answer is still `unknown` and the drink is tried as before.
- One limit, because the database rules are not in the repo (S1): if the rules
  hide a lobby row from somebody who is no longer a member, a member who left
  the lobby on another phone also gets "gone". That is the right result for
  them too (they cannot add drinks there any more), only the sentence names the
  host.
- Tests: `LobbyGoneTests` (which errors mean "gone", network errors do not) and
  three new cases in `LobbyOpenStateTests` (an empty answer is `gone`, an empty
  list in a failed reply is `unknown`). The former test "no row is unknown" is
  replaced, because that is exactly what this item changes.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, two phones in one lobby (A creator, B member):
  - B has the lobby open. A taps "Delete Lobby" twice. Within about 30 seconds
    B sees "This lobby was deleted by its host."; "OK" goes back to the hub and
    the lobby is gone from "Your Lobbies".
  - The same with B's quick add on and B's phone locked: tap 🍺 on the Lock
    Screen: the dialog says the lobby was deleted and the Live Activity goes.
  - B in flight mode with the lobby open: no message, the screen stays.
  - A deleting the lobby: A goes back to the hub as before, without the alert.
- Backlog: B20 ticked (checkbox only).
