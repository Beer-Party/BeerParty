# 2026-11-17: U1, lobby header without the UUID, with a share button

- The lobby header no longer shows "Lobby ID: <UUID>". The ID is of no use to a
  member and is still used internally.
- After "Reveal invite code" has fetched the code, a "Share invite code" button
  appears under it. It opens the system share sheet with a short text, for example
  `Join my BeerParty lobby “Friday” with invite code HOPS`.
- The code itself still hides after 10 seconds, as before. The share button stays
  until the lobby screen is left, so the share sheet is not pulled away while it is
  open. The code is kept in memory for that time, never written to disk.
- The share text is built by `LobbyInvite.shareMessage`, with unit tests in
  `LobbyInviteTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: open a lobby, tap "Reveal invite code", then "Share invite code":
  the share sheet opens with the lobby name and the right code; send it to Messages
  or Notes and check the text. Wait 10 seconds: the code line disappears, the share
  button stays and still works. The header no longer shows a UUID.
- Decision recorded: the share button appears only after a reveal, so no invite
  code is fetched until a member asks for it.
