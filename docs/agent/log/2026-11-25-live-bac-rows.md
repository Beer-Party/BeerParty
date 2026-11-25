# 2026-11-25: the "Live BAC" list shows photos, a bar per member and marks "You"

- One of five UI changes an owner asked for in the agent chat on 2026-11-25
  (a one-off request, not a backlog item, so `BACKLOG.md` is not changed).
- Before: "Live BAC" was a plain list of nickname and number.
- Now each line has the member's profile photo (the grey person symbol when
  there is none), the nickname, a "You" tag on the user's own line, the BAC
  value in semibold, and a thin bar underneath.
- The bar compares the members with each other: the highest BAC in the lobby
  gets a full bar, the others a share of it. So that one beer in a sober lobby
  does not fill the bar, a full bar stands for at least 0.5‰. The bar has one
  colour scale for everybody (the user's own is brighter); it is deliberately
  not green/yellow/red, because the app should not suggest that some level is
  "fine".
- Code: the section is its own view, `LiveBACSection`
  (`BeerParty/Features/Lobby/Views/`), which also takes this section out of
  `LobbyView` (helps Q2). What each line shows is worked out in `LiveBACRows`
  (`BeerParty/Features/Lobby/LiveBACRows.swift`), a plain function.
- Unit tests in `LiveBACRowsTests`: bar length (highest, relative, the 0.5‰
  floor, sober, out-of-range values), order, the "You" mark, where the photo
  comes from.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, in a lobby with at least two members and a few drinks:
  - Each line shows photo, name, bar and value; your own line has "You" and a
    brighter bar. The order is still highest BAC first.
  - A member without a photo shows the person symbol.
  - A long nickname is cut off with "…" and does not push the number away.
  - With VoiceOver, a line is read as "Anna, 0.45 per mille".
