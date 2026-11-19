# 2026-11-19: U7, "Leave Lobby" asks for a second tap

- "Closing Time" and "Delete Lobby" both need a confirming tap. "Leave Lobby"
  acted at once, and leaving deletes the member's drinks, BAC parameters and
  membership for that lobby with no way back.
- The button now works like the other two. The first tap turns it into "Confirm
  Leave Lobby" and the status line says "Leaving removes the drinks you logged in
  this lobby. Tap 'Confirm Leave Lobby' within 8 seconds to leave." After 8
  seconds without a second tap it goes back to "Leave Lobby".
- What leaving does is unchanged.
- No unit test: the change is view state only, in the same shape as the existing
  close and delete confirmations.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, as a member who did not create the lobby: (1) tap "Leave Lobby"
  once: the title changes, the status line explains, nothing is deleted. (2) Wait
  8 seconds: the title goes back. (3) Tap twice within 8 seconds: you leave the
  lobby as before.
- Backlog: U7 is one of the items proposed in pull request #27, which is not
  merged yet, so there is no line on `main` to tick and `BACKLOG.md` is not
  changed here (adding the line would conflict with #27). Once #27 is merged, a
  later run ticks U7.
