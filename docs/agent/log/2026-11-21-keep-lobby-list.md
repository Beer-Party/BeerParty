# 2026-11-21: B13, a failed refresh no longer empties "Your Lobbies"

- `PreLobbyView.loadMemberLobbies` set the list to empty whenever a request
  failed, so one bad moment of signal replaced the lobbies with an error line and
  there was no way into a lobby until the screen appeared again.
- A failed reload now keeps the rows already on screen and shows the error line
  under them. The line goes away after the next reload that works. It is kept
  apart from the "Joined lobby ..." and "Lobby ... created." messages, so one
  does not overwrite the other.
- The hub screen has pull-to-refresh, like the lobby screen. It reloads the
  profile photo and the lobby list.
- The "Loading lobbies..." spinner only shows while the list is empty, so a
  reload no longer makes the rows blink away and back.
- The row type and its sort order (open lobbies first, then newest) moved from
  the bottom of `PreLobbyView.swift` to
  `BeerParty/Features/Lobby/LobbyListItem.swift`. The order is unchanged.
- Not changed: a failed session check ("Could not load session") still empties
  the list, since there is then no signed-in user to show lobbies for.
- Unit tests in `LobbyListItemTests`: the order, a failed reload keeping the rows,
  a reload that works replacing them, and an empty result emptying the list.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: (1) with at least one lobby in the list, switch on Airplane Mode
  and pull down on the hub screen: the lobbies stay and a line says the lobbies
  could not be loaded. (2) Switch Airplane Mode off and pull down again: the line
  goes away. (3) Join or make a lobby: it appears in the list as before.
- Backlog: B13 is one of the items proposed in pull request #35, which is not
  merged yet, so there is no line on `main` to tick and `BACKLOG.md` is not
  changed here (adding the line would conflict with #35). Once #35 is merged, a
  later run ticks B13.
