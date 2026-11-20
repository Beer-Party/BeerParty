# 2026-11-20: five new backlog items, and yesterday's items ticked

- Every pull request from 2026-11-19 is merged, so no repairs were needed. The
  only item the agent could take today was the next part of Q2 (one part per
  run); everything else is tagged `needs-owner` or waits for S1 or for the
  `lobby_events` migration to be applied. The rest of the run went to reading the
  code for new work. No app code changed in this pull request.
- Ticked, because their pull requests are merged: **S8** (#28), **B10** (#31),
  **B11** (#32), **U7** (#29) and **U8** (#33). Yesterday's pull requests could
  not tick them, because the lines were not on `main` yet.
- Added, each with the place in the code it comes from:
  - **B12**: location sharing does not start the first time permission is given
    (`LocationTrackingService.startTracking` returns without `isTracking` set, so
    the permission callback does nothing).
  - **B13**: one failed refresh empties "Your Lobbies"
    (`PreLobbyView.loadMemberLobbies`), and that screen has no pull-to-refresh.
  - **B14**: a changed profile photo keeps showing the old one (same storage path
    every time, so the link is cached).
  - **U9**: the invite code is hidden while typing and is called "Lobby password"
    on one screen and "Invite code" on the others.
  - **S9** `needs-owner`: profile photos are in a public storage bucket, so
    anyone with the link can load them without signing in.
- Looked at and not added: joining a lobby you are already in (the creator
  included) overwrites your nickname and sets `lobby_members.role` to "guest".
  The app never reads `role` (rights come from `lobbies.created_by`), so nothing
  breaks today. Tell the agent if you want it as an item.
- These come from reading the code only; none was reproduced on a device.
- Human check: read the five items, then reorder, reword or delete them. B12,
  B13, B14 and U9 can be taken by the agent as they stand; S9 needs your decision.
