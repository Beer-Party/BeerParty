# 2026-11-18: B8, two members with the same nickname get their own lines

- The graph grouped and coloured its points by nickname, and the "newest point
  per member" used for the name label was keyed by nickname too. Two members who
  chose the same nickname were drawn as one zig-zag line with one label.
- `BACPoint` now carries the member's user id and a `label`. The chart's lines are
  keyed by user id, `BacGraphDisplayData.latestPointByMember` is keyed by user id,
  and colour, name label and the long-press read-out use the label.
- The label comes from the new `BACSeriesLabels`
  (`BeerParty/Features/Lobby/BACSeriesLabels.swift`): a nickname used once is kept;
  when several members share one (capitals and surrounding spaces ignored) the
  extra ones become "Anna (2)", "Anna (3)". The numbers follow user-id order, so
  every phone in the lobby shows the same ones.
- Not changed: the member list above the graph, the buddy picker and the map still
  show the plain nickname, so two Annas look the same there. Say so if you want
  the numbered label there too, or a rule that nicknames must be unique in a lobby
  (that one needs the database, so it waits for S1).
- Unit tests: `BACSeriesLabelsTests`, one new test each in `BACGraphWindowTests`
  and `BACCalculatorTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: join one lobby from two accounts with the same nickname and log
  drinks at different times on each. The graph shows two lines in two colours,
  labelled "Name" and "Name (2)"; long-press on each line shows the matching
  label. A lobby with different nicknames looks exactly as before.
