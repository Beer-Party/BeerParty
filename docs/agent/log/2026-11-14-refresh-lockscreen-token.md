# 2026-11-14: B4, Lock Screen quick-add token is kept fresh

- The Lock Screen buttons post drinks and votes with an access token saved in the
  app group. It was saved once when the lobby loaded and expired after about an
  hour. It is now replaced whenever it changes: on every auth event (which
  includes the hourly token refresh) and on the lobby's 30-second timer, which
  asks the auth client for the session and so also renews a token that is about
  to expire.
- The saved copy and the Live Activity are only rewritten when the token actually
  changed, so the 30-second check is normally a no-op.
- Verified: unit tests for the "replace or keep" rule. Build and tests: CI. Not
  tested on a device.
- Human check on a device: turn on Lock Screen Quick Add, leave the lobby screen
  open (or come back to it) for more than an hour, then add a drink from the Lock
  Screen. It should still work. Before this change it failed with a 401 error.
- Limit, needs an owner decision: iOS suspends the app when the phone is locked,
  so nothing runs to refresh the token. A phone that stays locked for more than an
  hour will still get the error until the app is opened again. Fixing that means
  the widget must renew the token itself, which requires storing the long-lived
  refresh token in the app group. That is a security trade-off for an owner to
  decide, so it is not done here.
