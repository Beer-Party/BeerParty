# 2026-11-17: Q2 part 1, the graph's time window moves out of `LobbyView`

- First step of splitting `LobbyView.swift`. The code that decides what the
  intoxication graph shows (the 2h / 5h / All timeframe, the pinch zoom, the
  20-minute minimum, the newest point per member and the axis ranges) was a private
  method on the view. It is now `BACGraphWindow.displayData` in
  `BeerParty/Features/Lobby/BACGraphWindow.swift`, a plain function with no UI.
- `BacGraphDisplayData` moved to the same file. `LobbyView.graphDisplayData` is now
  a five-line call into the new function, so the view body is untouched.
- The logic is copied as it was; no behaviour change is intended.
- `LobbyView.swift` goes from 1,834 to 1,785 lines.
- Unit tests in `BACGraphWindowTests`: empty graph, "All", a 2-hour timeframe, a
  timeframe longer than the history, pinch zoom and its limits, the newest point
  per member, and the y-axis floor.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: in a lobby with drinks over a few hours, switch between 2h, 5h and
  All, pinch in and out on the graph, and long-press to inspect a point. The graph
  should behave exactly as before.
- Next parts of Q2, one per run: system-event parsing (`isSystemEvent`,
  `closedAtTime`, ...), then the drink form and drink history as their own views.
