# 2026-11-26: B22, the Lock Screen vote buttons go away after a vote and when voting is over

- Before: `CastMotionVoteIntent` (the "Aye" and "Neigh" buttons of the Live
  Activity) sent the vote and changed nothing else. The buttons stayed, a
  second tap silently changed the vote, and on a locked phone they stayed
  after the motion had been decided: a tap then wrote a vote for a closed
  motion and still said "submitted".
- Now, in `BeerPartyWidget/AppIntent.swift`:
  - Before voting, the intent reads the motion's `status` (one small request,
    as the drink buttons do for the lobby). When the motion is decided or
    gone, it says "Voting on this motion is over.", takes the buttons away
    and sends no vote. Without an answer (offline, expired sign-in) it tries
    the vote as before.
  - After a vote that worked, it saves `shouldShowMotionVote = false` in the
    shared quick-add context and updates the Live Activity, so the two
    buttons disappear. The drink buttons stay.
- New in `LockScreenQuickAdd.swift` (shared by app and widget):
  `MotionVotingState` (reads the answer of the status request),
  `LobbyQuickAddContext.hidingMotionVote`, and `LobbyQuickAddStore.saveContext`
  / `loadContext`.
- Not changed: the app. An open lobby screen still writes the context from the
  motions it has loaded. If the screen is open in the foreground while the
  vote is cast from the Dynamic Island, a token refresh in the following
  seconds could show the buttons again until the next 30-second motion
  refresh. The database also still accepts a vote for a closed motion from a
  modified client; that rule belongs with S4.
- Tests: `MotionVotingStateTests` (active, closed, gone, no usable answer;
  hiding the buttons changes nothing else; save and read back).
- Verified: build and unit tests in CI. Not tested on a device; the Live
  Activity cannot be tried in CI at all.
- Human check, two phones A and B in one lobby, quick add switched on on A:
  - B opens a motion, A's lobby screen picks it up (within 30 seconds), then
    lock A. Tap "Aye" on the Lock Screen: "Aye vote submitted." and both vote
    buttons disappear; the drink buttons stay. B shows one aye.
  - New motion, lock A before voting. Let B vote so that the motion is
    decided (or wait for voting to close and keep B's lobby screen open).
    Then tap "Aye" on A: "Voting on this motion is over.", the buttons
    disappear and no vote is added.
- Backlog: B22 ticked (checkbox only).
