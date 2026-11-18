# 2026-11-18: B6, a decimal comma is accepted

- Drink volume, ABV and profile weight were read with `Double(text)`. On a phone
  set to a European region the decimal keypad types a comma, and `Double("4,7")`
  is nil, so "Add Drink" and "Save" stayed disabled with no explanation.
- New `DecimalInput.parse` in `BeerParty/Core/Services/DecimalInput.swift` accepts
  a comma or a point as the decimal separator, whatever the phone's region is.
  Anything that is not a plain number is rejected: empty text, letters, a minus
  sign, "1e3", and more than one separator ("1,234.5").
- Used in the four places `LobbyView` reads volume and ABV (add form and edit
  sheet) and the two places `ProfileSetupView` reads weight. Only those six lines
  changed.
- Not changed: how numbers are shown. The edit sheet and the weight field are
  still pre-filled with a point ("4.7"), which the parser also accepts.
- Unit tests in `DecimalInputTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: set the phone's region to Germany (Settings > General > Language &
  Region). In a lobby, type volume 330 and ABV 4,7: "Add Drink" becomes active and
  the drink is saved as 4.7 %. Edit that drink to 5,2 and save. In profile setup,
  type a weight such as 72,5 with kg selected: "Save" becomes active.
