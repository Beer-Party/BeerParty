# 2026-11-25: an empty "Your Lobbies" says what to do next

- One of five UI changes an owner asked for in the agent chat on 2026-11-25
  (a one-off request, not a backlog item, so `BACKLOG.md` is not changed).
- Before: a new user's hub showed one grey line, "You are not a member of any
  lobbies yet."
- Now: a small party symbol, "No lobbies yet", and one sentence pointing at the
  two buttons above: "Make Lobby" to start one and share its code, "Join Lobby"
  to enter a friend's code. New view `LobbyListEmptyState`
  (`BeerParty/Features/Lobby/Views/`).
- One fix along the way: when the list could not be loaded and nothing was
  shown before, the hub said both "You are not a member of any lobbies yet."
  and "Couldn't load your lobbies ...". Now only the error line is shown,
  because the app does not know whether there are lobbies.
- No unit tests: view code only.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check:
  - An account that is in no lobby: the hub shows the symbol, "No lobbies
    yet" and the sentence, centred in the "Your Lobbies" card.
  - Same account in flight mode, after restarting the app: only the error line
    is shown.
  - An account with lobbies: nothing changed.
