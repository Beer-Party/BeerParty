# 2026-11-22: Q2 part 6, the drink form's text moves out of `LobbyView`

- Sixth step of splitting `LobbyView.swift`. The lobby screen kept six text
  properties for its two drink forms (name, volume and ABV for "Add Drink", and
  the same three for the "Edit Drink" sheet) plus ten small computed properties
  that trimmed, parsed and checked them.
- These are now one plain type, `DrinkDraft`
  (`BeerParty/Features/Lobby/DrinkDraft.swift`): the three texts, the parsed
  volume and ABV, the too-large message and `canSubmit`. The screen holds two of
  them, `drinkDraft` and `editDraft`.
- The "Edit Drink" sheet is its own view, `DrinkEditSheet`
  (`BeerParty/Features/Lobby/Views/DrinkEditSheet.swift`). It only shows the form;
  the lobby screen still owns the draft and does the saving.
- The logic is copied as it was; no behaviour change is intended. One thing was
  kept on purpose although it looks wrong: the name of the widget's custom button
  is read after the form has been cleared (see "Found while doing this").
- `LobbyView.swift` goes from 1,846 to 1,754 lines.
- Unit tests in `DrinkDraftTests`: empty form, filled form, decimal comma, a name
  of only spaces, volume zero, ABV zero, values above the limits, and filling the
  form from a drink that is being edited.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, in an open lobby: (1) "Add Drink" stays disabled until name,
  volume and ABV are filled in; type ABV 400 and the red line "ABV can be at most
  100 %." appears; a valid drink is added and the three fields are emptied.
  (2) In "My Drinks Tonight" tap "Edit" on a drink added less than 15 minutes
  ago: the sheet opens with the drink's values, "Save" changes it, "Cancel"
  closes the sheet without a change.
- Backlog: adds the "Part 6" line under Q2, and the "Part 5" line that
  yesterday's pull request #40 could not add.
- Found while doing this: `addManualDrink` builds the widget's custom button from
  the drink name after `addDrink` has already emptied the form, so the custom
  button probably gets an empty name. Not changed here (this pull request only
  moves code); it is in today's backlog pull request as B18.
- Next parts of Q2, one per run: the "Add Drink" section and the drink history
  as their own views, then the motions section.
