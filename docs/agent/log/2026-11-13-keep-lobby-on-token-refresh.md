# 2026-11-13: B1, token refresh no longer tears down the lobby

- `AuthViewModel.refreshProfileState` runs on every auth event, including the
  hourly token refresh, and used to set `profileState = .unknown` first. `RootView`
  then showed the "Checking profile..." spinner in place of `PreLobbyView`, which
  discards the lobby pushed on top of it.
- The view model now remembers which user's profile it has confirmed. For that
  user the state stays `.complete` while the profile is re-checked, and a re-check
  that fails (offline, timeout) no longer sends them to profile setup. Signing out
  forgets the confirmation.
- Not changed: the first check after launch still treats any error as "no
  profile". That is B2.
- Verified: unit tests for the state rule. Build and tests: CI. The view-level
  behaviour cannot be tested here.
- Human check on a device: stay in a lobby for more than an hour (or until a
  token refresh; the default access token lifetime is one hour) and confirm the
  lobby stays on screen. Also: sign out and sign in as a user without a profile,
  and confirm profile setup still appears.
