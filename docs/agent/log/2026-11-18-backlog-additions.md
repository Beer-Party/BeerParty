# 2026-11-18: five new backlog items, and B9 split

- Today's five code pull requests take every item the agent can work on (B6, B7,
  B8, B9 and one part of Q2). Everything else is tagged `needs-owner` or waits
  for S1 or for the `lobby_events` migration to be applied. So the sixth slot of
  this run went to reading the code for new work. No app code changed in this PR.
- Added, each with the place in the code it comes from:
  - **S8**: signing out leaves the Lock Screen quick-add working as the previous
    user for up to an hour, and its access token on disk
    (`PreLobbyView.signOut` never calls `LobbyLiveActivityService.endContext()`).
  - **B10**: a failed "Make Lobby" leaves a lobby row with no members, and the
    invite code is then "already in use" (`MakeLobbyView.createLobby`, four
    separate requests).
  - **B11**: the Lock Screen quick-add still adds drinks after the lobby is
    closed (`QuickAddDrinkIntent` has no closed-lobby check).
  - **U7**: "Leave Lobby" deletes your drinks on one tap, while close and delete
    ask twice.
  - **U8**: the Lock Screen dialogs show developer text and raw server responses.
- Also added **B9b** (after S1): the database check constraint that B9 asked for.
  It is the part of B9 that today's B9 pull request could not do, written down
  so it is not lost when B9 is ticked.
- Looked at and not added: nicknames, lobby names and drink names have no length
  limit, and the profile accepts any age above 0 and any weight above 0. Both are
  real but need a decision from you on the limits (and, for age, whether the app
  should refuse people under the legal drinking age). Tell the agent if you want
  them as items.
- These come from reading the code only; none was reproduced on a device.
- Human check: read the six items, then reorder, reword or delete them. All
  except B9b can be taken by the agent as they stand.
