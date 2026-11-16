# 2026-11-16: B2, a failed profile check no longer means "no profile"

- `AuthViewModel.refreshProfileState` asked for the profile row with `.single()`,
  which throws both when there is no row and when the request fails. Every error
  was read as "no profile", so an existing user who opened the app offline landed
  on profile setup.
- The lookup now asks for a list of at most one row. An empty list means a new
  user (profile setup). A thrown error means the request failed.
- New state `ProfileState.checkFailed`: `RootView` shows "Couldn't load your
  profile" with a "Try again" button. A user whose profile was already confirmed
  in this session stays in the app when a re-check fails, as before (B1).
- The result of a check is dropped if the user signed out or changed while the
  request was running.
- The decision is a pure function, `ProfileState.afterCheck`, with unit tests in
  `ProfileStateTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: (1) sign in, close the app, turn on Airplane Mode, open the app:
  the retry screen appears, not profile setup; turn Airplane Mode off and tap
  "Try again": the lobby list appears. (2) A brand-new account still gets profile
  setup, and finishing it still leads into the app.
- Skipped today because open PRs #7 and #11 edit the same parts of
  `LobbyView.swift`: Q2, Q4, U1, U2, U3. B5 step 3 waits for step 2 (owner applies
  the migration).
