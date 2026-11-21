# 2026-11-21: U9, the invite code is shown while typing and has one name

- "Join Lobby" asked for the invite code in a hidden field, and "Make Lobby"
  asked for the same thing as "Lobby password", also hidden. The code is sent to
  friends with the share button and can be shown in the lobby, so hiding it while
  typing protected nothing, and a typo when joining only showed up as "No active
  lobby found for that invite code."
- Both screens now use a normal text field called "Invite code", with
  autocorrection and automatic capitals off, as before.
- "Make Lobby" has a line under the fields: "Friends join with the invite code.
  Use at least 4 characters." Before, "Create" stayed grey for a short code with
  no reason given.
- Not changed: what counts as a valid code, how lobbies are made or joined, and
  the "Reveal invite code" button in the lobby.
- No unit test: the change is two text fields and their labels, with no logic.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: (1) "Make Lobby": the third field reads "Invite code", what you
  type is visible, and the line about 4 characters is under the fields. Create a
  lobby with a code. (2) On a second account, "Join Lobby": the code is visible
  while typing, and joining with it works. (3) Neither field changes the first
  letter to a capital or autocorrects the code.
- Backlog: U9 is one of the items proposed in pull request #35, which is not
  merged yet, so there is no line on `main` to tick and `BACKLOG.md` is not
  changed here (adding the line would conflict with #35). Once #35 is merged, a
  later run ticks U9.
