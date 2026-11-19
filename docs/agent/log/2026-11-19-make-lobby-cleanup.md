# 2026-11-19: B10, a failed "Make Lobby" no longer blocks its invite code

- `MakeLobbyView.createLobby` sent four separate requests: the `lobbies` row, then
  the creator's `lobby_members`, `member_state` and BAC-parameter rows. When one of
  the later ones failed, the lobby row stayed with no members. It appeared in
  nobody's list, and trying again said "That invite code is already in use".
- The steps moved, unchanged, into `LobbyBackendService.createLobby`. Two things
  are new:
  1. When a step after the lobby row fails, the lobby row and the creator's rows
     are deleted again (same order as `deleteLobby`) and the user sees the original
     error.
  2. That clean-up also fails when the connection is gone, which is the likely
     cause. So before the "already in use" check, a lobby with this invite code
     that this user created and that has no members is treated as a leftover and
     removed. Trying again with the same code then works.
- The "create, finish, undo on failure" order is `LobbyCreation.perform`, a plain
  function with unit tests (`LobbyCreationTests`). The requests themselves need a
  server and are not unit-tested.
- "That invite code is already in use" is now `LobbyCreationError.inviteCodeInUse`
  and shown through `UserFacingError` like the other app errors.
- Limits: (1) this is still several requests from the phone; the proper fix is one
  `create_lobby` database function, which waits for S1. (2) It relies on the
  database letting the creator delete their own lobby row, as "Delete Lobby"
  already does. If that is refused, the user gets "already in use" as before.
  (3) If someone joins with the code in the moment between the lobby row and the
  failure, the leftover has a member and is left alone (the code stays taken).
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: (1) make a lobby as usual: you land in it as before, and it shows
  in your list. (2) Try a code that another lobby uses: "That invite code is
  already in use. Pick a different one." (3) If you can, turn on flight mode right
  after tapping Create to make it fail part-way, go online and create again with
  the same code: it now works.
- Backlog: B10 is one of the items proposed in pull request #27, which is not
  merged yet, so there is no line on `main` to tick and `BACKLOG.md` is not
  changed here (adding the line would conflict with #27). Once #27 is merged, a
  later run ticks B10.
