# 2026-11-23: Q2 part 7, the "Drink History" section moves out of `LobbyView`

- Seventh step of splitting `LobbyView.swift`. The "Drink History" section (the
  "My Drinks Tonight" list with "Edit" and "Delete") was about 50 lines inside
  the screen's `body`.
- It is now its own view, `DrinkHistorySection`
  (`BeerParty/Features/Lobby/Views/DrinkHistorySection.swift`). It only shows the
  list; the lobby screen still owns the drinks and does the editing and deleting.
- The two rules behind it moved to a plain type, `DrinkHistory`
  (`BeerParty/Features/Lobby/DrinkHistory.swift`): which drinks are listed (the
  user's own, newest first) and which can still be changed (own drink, open
  lobby, added no more than 15 minutes ago, not a system-event row). `LobbyView`
  keeps `canModifyDrink` as a one-line call, because saving and deleting use it
  too.
- The code is copied as it was; no behaviour change is intended.
- `LobbyView.swift` goes from 1,754 to 1,706 lines.
- Unit tests in `DrinkHistoryTests`: the list and its order, and each condition
  for changing a drink including the 15-minute limit.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, in an open lobby: with no drinks the section says "No drinks
  logged yet." Add two drinks: "My Drinks Tonight (2)" opens to both, newest on
  top, each with "Edit" and "Delete". "Edit" opens the sheet with the drink's
  values, "Delete" removes the drink. A drink older than 15 minutes shows
  neither button.
- Why this part while other pull requests from today also change `LobbyView`:
  B16 (location) and B18 (custom button) change other functions, more than 100
  lines away from these, so all three merge in any order.
- Backlog: adds the "Part 7" line under Q2.
- Next parts of Q2, one per run: the "Add Drink" and "Widget" sections as their
  own views, then the motions section, then the map.
