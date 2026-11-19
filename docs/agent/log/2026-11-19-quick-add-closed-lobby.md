# 2026-11-19: B11, Lock Screen quick-add stops adding drinks to a closed lobby

- The app's `insertDrink` refuses when the lobby is closed, but the Lock Screen
  buttons (`QuickAddDrinkIntent`) posted straight to `drinks`. The Live Activity is
  ended only if the phone has the lobby screen open when the lobby closes, so a
  locked phone kept its buttons and its drinks landed in a closed lobby.
- Before adding, the intent now asks for the lobby's `is_active` and `created_at`
  (one small request, 6-second timeout). When the lobby is closed it adds nothing,
  says "This lobby is closed. Drinks can no longer be added." and tries to end the
  Live Activity.
- "Closed" also covers a lobby that is still marked active but was made more than
  24 hours ago: the app closes those the next time someone opens it, and a locked
  phone should not get in before that.
- When the check gives no answer (offline, sign-in expired, lobby row not
  returned), the drink is sent as before and succeeds or fails as before. The
  check can only stop a drink when the server says the lobby is closed.
- The decision is `LobbyOpenState.from(statusCode:body:now:)` in the file shared
  by app and widget, with unit tests in `LobbyOpenStateTests`.
- Not changed: the vote buttons, the saved context (the app clears it when the
  lobby screen is next opened), and the texts of the other dialogs (U8). A database
  rule that refuses drinks for a closed lobby belongs with S1.
- Verified: build and unit tests in CI. Not tested on a device. CI cannot tell
  whether the intent, which runs in the widget extension, is allowed to end the
  Live Activity; if it is not, the buttons stay but only show the message.
- Human check, two phones in one lobby: (1) on phone B switch "Lock Screen quick
  add" on and lock it. (2) On phone A tap "Closing Time" twice. (3) On B's Lock
  Screen tap Beer: the message says the lobby is closed, no drink appears on A,
  and please note whether the Live Activity disappears. (4) In an open lobby the
  buttons add drinks as before, with no noticeable extra delay.
- Backlog: B11 is one of the items proposed in pull request #27, which is not
  merged yet, so there is no line on `main` to tick and `BACKLOG.md` is not
  changed here (adding the line would conflict with #27). Once #27 is merged, a
  later run ticks B11.
