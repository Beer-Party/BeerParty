# 2026-11-17: U2, status lines no longer show raw error text

- 22 places put `error.localizedDescription` straight into a status line, for
  example "Failed to add drink: The operation couldn’t be completed.
  (NSURLErrorDomain error -1009.)" or a raw database message.
- New `UserFacingError.message(couldNot:error:)` in
  `BeerParty/Core/Services/UserFacingError.swift` builds the line instead:
  - offline: "Couldn't add the drink. You seem to be offline. Check your connection
    and try again."
  - timeout: "... The server took too long to answer. Please try again."
  - server unreachable: "... The server can't be reached right now. Try again in a
    moment."
  - anything else: "Couldn't add the drink. Please try again."
  - the app's own errors (`LobbyJoinError`, `LobbyLifecycleError`,
    `DrinkMutationError`, `ProfileImageError`) already carry a sentence written for
    the user, such as "No active lobby found for that invite code."; those are shown
    unchanged, without a prefix.
- Used in `LobbyView` (14 places), `ProfileSetupView` (3), `PreLobbyView` (2),
  `LobbyLoginView`, `MakeLobbyView` and the fallback in `LoginView`. Only the
  message line changed at each place.
- Not changed: the two dialogs in the widget's `AppIntent.swift` (a separate
  target, which cannot see this helper yet).
- Trade-off: the technical detail is no longer visible on screen, which makes a
  bug report from a user less specific. If you want it back for debugging, say so
  and a later run can log it in debug builds.
- Unit tests in `UserFacingErrorTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: (1) in a lobby, turn on Airplane Mode and tap a quick-add button:
  the status line reads "Couldn't add the drink. You seem to be offline. ...".
  (2) Join with a wrong invite code: "No active lobby found for that invite code."
  (3) Pull to refresh the lobby list offline: "Couldn't load your lobbies. You seem
  to be offline. ...".
