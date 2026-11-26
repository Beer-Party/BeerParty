# 2026-11-25: Q2 part 9, the "Motions" section moves out of `LobbyView`

- Ninth step of splitting `LobbyView.swift`. The "Motions" section (the form
  for a new motion and the folded list of past motions) was about 60 lines
  inside the screen's `body`.
- It is now `BeerParty/Features/Lobby/Views/MotionsSection.swift`. It only
  shows things; the lobby screen still creates the motion, keeps the list up
  to date and decides the results (`MotionTally`). The choices of the "In"
  picker (5 to 45 minutes) moved with it as `MotionsSection.delayOptions`.
- The code is copied as it was. No behaviour change is intended.
- The "Active Motion" section at the top of the screen is not moved today: it
  sits right above "Live BAC", which #52 changes, and moving it now would make
  the two pull requests conflict. It is the next part.
- `LobbyView.swift` goes from 1,688 to 1,638 lines.
- No new unit tests: view code only. The rules behind it (`MotionTally`,
  the voting window) already have tests, and they still pass.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, in an open lobby:
  - "Create Motion" is grey until something is typed in "Motion towards...";
    the "In" picker offers 5 to 45 minutes.
  - Create a motion: the field empties, "One active motion at a time." appears
    and the button is grey until the motion is decided.
  - "Past Motions (n)" opens and shows each motion with its votes and
    "Passed" or "Did not pass".
  - In a closed lobby: "Lobby is closed. New motions are disabled." and the
    past motions are still listed.
- Other open pull requests: #51 changes `LobbyView` a few lines below
  ("Drink History" and the status line), #59 changes the "Made it home" button
  above; neither touches these lines (checked against their diffs).
- Backlog: adds the "Part 9" line under Q2.
- Next parts of Q2, one per run: the "Active Motion" section (after #52), then
  the map, then the graph.
