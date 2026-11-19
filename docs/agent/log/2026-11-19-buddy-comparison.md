# 2026-11-19: Q2 part 3, the buddy comparison moves out of `LobbyView`

- Third step of splitting `LobbyView.swift`. The sum behind the "buddy" section
  (who is ahead, the BAC difference and how many standard beers that is) was a
  private method on the view plus a private struct at the end of the file. It is
  now `BuddyComparison.compare` and `BuddyComparisonData` in
  `BeerParty/Features/Lobby/BuddyComparison.swift`, a plain function with no UI.
- `LobbyView.buddyComparison(from:)` keeps its name and is now a call into the new
  function, so the view body is untouched. The `standardBeerGrams` constant moved
  with the sum.
- The logic is copied as it was; no behaviour change is intended.
- `LobbyView.swift` goes from 1,817 to 1,794 lines.
- Unit tests in `BuddyComparisonTests`: no buddy chosen, a member missing from the
  snapshot, ahead, behind, even, and the beer gap with saved and with default body
  parameters.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: in a lobby with two members who have logged different drinks, pick
  the other member under "Buddy". The three lines (ahead or behind, BAC difference,
  standard beers) read as before.
- This part touches none of the lines changed by the open pull requests #22 to #26.
- Backlog: the "Part 3" line under Q2 is not added in this pull request. The line
  for part 2 is added at the same place by #26, which is still open, so adding it
  here would conflict. A later run adds it once #26 is merged.
- Next parts of Q2, one per run: the graph's long-press inspection
  (`updateInspectedPoint`, `pointDistanceScore`), then the drink form and drink
  history as their own views.
