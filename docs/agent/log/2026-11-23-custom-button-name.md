# 2026-11-23: B18, the widget's custom button keeps its name

- The bug: `LobbyView.addManualDrink` added the drink first and then built the
  Lock Screen custom button from the form's name. `addDrink` empties the form
  when it succeeds, so the button was saved with the right volume and ABV but
  the name "". The "Custom button:" line showed no name, and a drink added with
  that button from the Lock Screen had an empty name in the drink history.
- The name is now read once, before the drink is added, and used for both.
- The button is built by `QuickAddDrinkPreset.custom(name:volumeMl:abv:)`
  (`BeerParty/Features/Lobby/CustomQuickAddPreset.swift`), which returns nothing
  for an empty name, so a nameless button can no longer be saved.
- Not reproduced on a device first, as the backlog item suggested: this
  workspace cannot run the app. The fix is safe either way, because reading the
  name earlier gives the same result when the bug does not occur.
- A custom button already saved with an empty name stays until the next manual
  drink is added with "Use as widget custom button" on.
- Unit tests in `CustomQuickAddPresetTests`: the values are carried over, the
  name is trimmed, an empty name makes no button, the id is "custom".
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, in an open lobby with the widget switched on: add a manual drink
  ("Cider", 330, 4.5) with "Use as widget custom button" on. The line reads
  "Custom button: Cider • 330 ml • 4.5%". Tap the custom button on the Lock
  Screen: the drink history shows "Cider".
- Backlog: ticks B18.
