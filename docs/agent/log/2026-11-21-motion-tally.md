# 2026-11-21: Q2 part 5, the motion vote count moves out of `LobbyView`

- Fifth step of splitting `LobbyView.swift`. Deciding a motion (is voting over,
  did it pass, is it time to announce it) was inline in
  `LobbyView.resolveAndNotifyMotionsIfNeeded`. The rules are now
  `MotionTally.outcome` and `MotionTally.shouldAnnounceArrival` in
  `BeerParty/Features/Lobby/MotionTally.swift`, plain functions with no UI.
- The view keeps the network calls and now asks those two functions what to do.
- The logic is copied as it was; no behaviour change is intended. A motion still
  passes with more than two thirds of all members voting aye, and the phone
  still decides (moving that to the server is S4).
- Unit tests in `MotionTallyTests`: voting still open, everyone voted, time run
  out, exactly two thirds not passing, members who did not vote, one member, no
  known members, and when the arrival is announced.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, in a lobby with three members: (1) propose a motion, two vote aye
  and one neigh: it fails (two thirds is not "more than two thirds"). (2) Propose
  another, all three vote aye: it passes as soon as the third vote is in, and at
  its time the status line says "Motion time: Head towards ...".
- Why a second Q2 part while part 4 (#34) is still open: the rule is one part per
  run, #34 is yesterday's, and this part changes lines about 70 lines away from
  the ones #34 changes, so the two merge in either order.
- Backlog: not changed here. The "Part 5" line would sit right under the "Part 3"
  and "Part 4" lines that #34 adds, and would conflict with it. A later run adds
  the line once #34 is merged.
- Next parts of Q2, one per run: the drink form, then the drink history, as their
  own views.
