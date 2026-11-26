# 2026-11-26: Q2 part 10, the "Buddy" section is its own view

- Moved the "Buddy" section (the picker and the comparison lines) out of
  `LobbyView.body` into `BuddySection`
  (`BeerParty/Features/Lobby/Views/BuddySection.swift`). `LobbyView` still
  owns the chosen buddy and works out the comparison; the section gets them
  as values and a binding, like the sections moved in parts 7 to 9.
- The headline ("You are ahead of Sam.", "You are behind Sam.", "You and Sam
  are neck-and-neck.") is now `BuddyComparisonData.headline`, a plain
  property with two new tests in `BuddyComparisonTests`. Same words as
  before.
- No behaviour change intended. `LobbyView.swift` goes from 1,711 to 1,681
  lines.
- What is left in `LobbyView.body` for later parts: the header, "Active
  Motion", the graph, the map, "Lobby Actions" and the quick-add emoji row.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, a lobby with two members who both have drinks:
  - The "Buddy" section shows the picker; choosing the other member shows
    the headline, "BAC difference" and "About ... standard beers" exactly as
    before; "None" hides them.
  - Alone in a lobby: "Buddy comparison appears once another member joins."
- Backlog: Q2 part 10 added and ticked.
