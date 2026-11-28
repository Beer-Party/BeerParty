# 2026-11-28: B25, names have a maximum length

- Why: the nickname, the lobby name, a drink's name and a motion's
  destination were only checked for not being empty. A pasted sentence as a
  nickname is shown on every phone in the lobby and breaks the "Live BAC"
  list, the graph labels, the status banner and the Lock Screen activity.
- New: `NameLimits` (no UI, no network). Nickname 24, lobby name 40, drink
  name 40, motion destination 60 characters, counted after trimming and as
  the user sees them (an emoji is one). `NameLimits.message` gives the line
  for the form, `NameLimits.check` throws `NameLimitError` for the service.
- Where it is typed: the field does not stop at the limit. A red line under
  it says for example "Nickname can be at most 24 characters (now 31)." and
  the button is off until the text fits. This is how volume and ABV limits
  already work (`DrinkDraft.limitMessage`), and nothing is cut off silently
  when a text is pasted.
  - "Join Lobby": nickname.
  - "Make Lobby": lobby name and nickname.
  - "Add Drink" and the "Edit Drink" sheet: drink name, through
    `DrinkDraft.limitMessage` (the name's line comes before the volume and
    ABV lines).
  - "Motions": destination.
- Checked again in `LobbyBackendService`, at the top of `joinLobby`,
  `createLobby`, `insertDrink`, `updateDrink` and `createMotion`.
  `UserFacingError` shows `NameLimitError` as it is.
- Things to know:
  - The database refuses a nickname of 30 characters or more; 24 is below
    that. It has no limit for the other three names, so a modified client
    can still save long ones. A migration can add them (not in this change).
  - Names saved before this change stay as they are. A drink with a longer
    name can be edited only after its name is shortened. A remembered
    nickname of 25 to 29 characters is still filled in on "Join Lobby", with
    the red line under it.
  - The widget's custom button takes its name from the drink, so it is
    limited with it. The Lock Screen buttons have fixed names; the widget
    target is not changed.
  - `LobbyView.swift` is not changed.
- Tests: `NameLimitsTests` (the limits, trimming, emoji, the messages, the
  thrown error and how it is shown, the drink form with a long name).
- Verified: build and unit tests in CI. Not tried on a screen.
- Human check on a device:
  - "Join Lobby" with a nickname of 25 or more characters: red line, "Join"
    is off; shorten it and "Join" works.
  - "Make Lobby" with a long lobby name: the same, and the sheet still fits
    with the keyboard open.
  - "Add Drink" with a name of more than 40 characters: red line, button
    off. The same in "Edit Drink".
  - A motion with a destination of more than 60 characters: red line,
    "Create Motion" off.
- Backlog: B25 ticked.
