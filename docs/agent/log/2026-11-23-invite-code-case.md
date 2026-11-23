# 2026-11-23: U10, invite codes work in capital or small letters

- The problem: `joinLobby` looked the code up with an exact match, so a friend
  told "beer" who typed "Beer" only saw "No active lobby found for that invite
  code". "Make Lobby" checked that a code was free in the same exact way, so
  "Beer" could be created next to "beer".
- Both lookups now ask the database for a case-insensitive match (`ilike`) and
  then choose among the rows in the app:
  - `LobbyInvite.caseInsensitivePattern(for:)` escapes `%`, `_` and `\` in the
    typed code so they only match themselves.
  - `LobbyInvite.match(typed:among:)` picks the lobby. Rows that differ in more
    than case are dropped (the database API treats `*` in a pattern as
    "anything" and offers no way to escape it, so the app checks again).
- One deliberate difference from the backlog text: when two existing lobbies
  have codes that differ only in case ("beer" and "Beer"), typing one of them
  exactly still joins that lobby, as it does today. The "Multiple lobbies share
  that invite code" message appears only when the typed code fits several and
  is spelled exactly like none (or like more than one). Otherwise this change
  would have locked people out of both lobbies.
- "Make Lobby" now refuses a code that an existing lobby holds in any case.
- The lasting fix (generated codes, joining through a database function) is
  S2. No database change here.
- Unit tests in `InviteCodeMatchTests`: the escaping, comparing without case,
  and choosing among none, one, several and exactly spelled codes.
- Verified: build and unit tests in CI. The `ilike` request itself is not
  covered by a test (it needs the database) and was not tried on a device.
- Human check: make a lobby with the code "beer". On a second account join with
  "Beer" and with "BEER": both get in. Join with "bee%" or "be*": "No active
  lobby found for that invite code". Try to make a second lobby with the code
  "BEER": "That invite code is already in use".
- Backlog: ticks U10.
