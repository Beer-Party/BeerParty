# 2026-11-20: Q2 part 4, the graph's long-press point choice moves out of `LobbyView`

- Fourth step of splitting `LobbyView.swift`. Choosing which graph point a long
  press is pointing at (nearest in time, then nearest in BAC) was two private
  methods on the view. The sum is now `BACGraphInspection.nearestPoint` and
  `distanceScore` in `BeerParty/Features/Lobby/BACGraphInspection.swift`, plain
  functions with no UI.
- `LobbyView.updateInspectedPoint` keeps the part that needs the chart (turning
  the finger position into a time and a BAC value) and then calls the new
  function. The view body is untouched.
- The logic is copied as it was; no behaviour change is intended. The two numbers
  in it (120 seconds, 0.05 minimum height) now have names.
- `LobbyView.swift` goes from 1,856 to 1,830 lines.
- Unit tests in `BACGraphInspectionTests`: no points, nearest in time, two lines at
  the same time, no BAC value, a tie, and the two weights.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: in a lobby with drinks from two members, press and hold on the
  graph and drag. The caption under the graph shows the name, time and BAC of the
  point under the finger, and follows the nearer line when two lines are close.
- Backlog: adds the "Part 4" line under Q2, and the "Part 3" line that
  yesterday's pull request #30 could not add.
- Next parts of Q2, one per run: the drink form, then the drink history, as their
  own views.
