# 2026-11-23: B17, a motion "in 5 min" is decided at its time

- The bug: voting on a motion always stayed open for 10 minutes, but the delay
  picker starts at 5 minutes. When one member did not vote, a five-minute motion
  was decided only after 10 minutes, so "Motion time: Head towards ..." came five
  minutes after the agreed time.
- New motions now close voting after 10 minutes or at the motion's own time,
  whichever comes first: `MotionTally.votingClosesAt(createdAt:targetAt:)`, used
  by `LobbyBackendService.createMotion`. Only the 5-minute choice changes; 10
  minutes and longer behave as before.
- The "Voting closes ... or when all members vote." line already shows the saved
  closing time, so it now counts down to the motion's time for a 5-minute
  motion. No change to the screen code.
- No database change. `close_expired_motions` and the voting rules only read
  `voting_closes_at`. The table requires `voting_closes_at >= created_at`
  (server clock); a phone whose clock is more than five minutes behind could
  now be refused for a 5-minute motion, where the margin used to be ten minutes.
- Motions that are already open keep the closing time they were saved with.
- Unit tests in `MotionVotingWindowTests`: 5, 10, 15 and 45 minutes, a target
  that is not in the future, and a five-minute motion being decided and
  announced at its time.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, in a lobby with at least two members: propose a motion "in 5
  min"; the line reads "Voting closes in 5 min ...". One member votes aye and the
  other does not vote. After five minutes (within the 30-second refresh) the
  motion is decided, and if it passed the status line says "Motion time: Head
  towards ...". A motion "in 15 min" still shows "Voting closes in 10 min".
- Backlog: ticks B17.
