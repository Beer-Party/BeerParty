# 2026-11-26: Q9, the motions are fetched once per refresh, not twice

- Before: every 30 seconds `refreshMotionsIfNeeded` loaded motions and votes
  (two requests), and `resolveAndNotifyMotionsIfNeeded` then always loaded
  both again, also when no motion had been closed, which is nearly always.
  Four requests per phone every 30 seconds just for motions.
- Now: the second load happens only when this phone has just closed a motion
  (it needs the result from the server before it can announce "Motion
  time"). Otherwise the list fetched a moment earlier is used. Two requests
  per refresh instead of four.
- Which motions are due for closing moved from a loop in `LobbyView` to
  `MotionTally.closings`, a plain function with tests; the second load
  happens exactly when it returns something.
- Not fetched again after announcing: the backlog item also names "wrote a
  'motion due' note" as a reason. The old code did not fetch after that
  either, nothing on the screen depends on `notified_at`, and the next
  30-second refresh brings it. `notifyMotionArrivalIfNeeded` checks the row
  on the server before writing, so a stale local value cannot announce twice.
- Behaviour is otherwise the same: same closing rule, same announcement.
- Tests: `MotionClosingsTests` (nothing to close, open vote, already decided,
  everyone voted, time ran out, a mix).
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, two phones in one lobby:
  - Open a motion "in 5 min", both vote aye: within 30 seconds both phones
    show it under past motions as passed, and at its time one of them shows
    "Motion time: Head towards ..." and the other gets the same line.
  - Open a motion and let nobody else vote: after voting closes it shows as
    failed on both phones.
- Backlog: Q9 ticked (checkbox only).
