# 2026-11-19: S8, signing out ends the Lock Screen quick-add

- Signing out only called `supabase.auth.signOut()`. The quick-add context in the
  shared app group (it holds the user's access token) and the Live Activity stayed,
  so the Lock Screen buttons kept adding drinks and votes as the previous user
  until the token expired (up to an hour), and the token stayed on disk.
- `PreLobbyView.signOut` now calls `LobbyLiveActivityService.endContext()` before
  the sign-out request, so the buttons are gone even when that request fails.
- `AuthViewModel` does the same whenever the auth client reports that there is no
  session any more (a refresh that was refused, for example).
- The removal of the saved context is now one function,
  `LobbyQuickAddStore.removeContext(from:)`, used by `endContext()`. The custom
  drink presets are kept; they hold no account data.
- Unit tests in `LobbyQuickAddStoreTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: (1) in a lobby, switch "Lock Screen quick add" on, go back to the
  lobby list and tap "Sign Out": the Live Activity disappears from the Lock Screen
  at once. (2) Sign in again and open the lobby: with the toggle on, the Live
  Activity comes back and adds drinks as before.
- Backlog: S8 is one of the items proposed in pull request #27, which is not
  merged yet, so there is no line on `main` to tick and `BACKLOG.md` is not
  changed here (adding the line would conflict with #27). Once #27 is merged, a
  later run ticks S8.
