# 2026-11-25: four new backlog items

- Five `agent` pull requests from earlier today (#51 to #55) were open at the
  start, all with green CI, no merge conflict and no review comments, so no
  repairs were needed. No `agent-queue` issue is open.
- This run took every backlog item that was free: B19 (#56), B20 (#57), B21
  (#58), U12 (#59) and Q2 part 9 (#60). U11 is covered by #53. Everything else
  is tagged `needs-owner` or waits for S1 or for the `lobby_events` migration
  to be applied, so this sixth pull request adds new items instead. No app
  code changed here.
- Added, each with the place in the code it comes from:
  - **B22**: the Lock Screen vote buttons stay after voting from the Lock
    Screen, a second tap changes the vote, and on a locked phone they still
    vote after the motion has been decided.
  - **B23**: the profile accepts any weight and age; a slip such as 750 kg
    makes that member's BAC about ten times too low for the whole lobby. A
    minimum age is left to the owners.
  - **B24**: failures of the timed BAC write and of location updates put an
    error into the status line again and again while the phone has no
    signal. Matters more once the status banner (#51) is merged.
  - **Q9**: the motions are fetched twice every 30 seconds (four requests per
    phone) although nothing changed.
- Placement: the new items go at the end of "Bugs" and "Code health". None
  goes at the end of "UX", because #53 and #59 change the last two items
  there and an addition right after them would make the pull requests
  conflict. That is also why B23 and B24, which are partly UX, are numbered
  as bugs.
- Looked at and not added:
  - "Join Lobby" with the code of a lobby the user created changes their
    `lobby_members.role` from "admin" to "guest" (the join is an upsert with
    role "guest"). Nothing in the app reads the role (the creator is
    recognised by `lobbies.created_by`), so it only matters if the database
    rules use it, which S1 will show.
  - The two items from 2026-11-24 that were left for the owners (the Live
    Activity keeps the first lobby's name; the unread `bac_estimate` write)
    are still open questions; tell the agent if you want either.
- These come from reading the code only; none was reproduced on a device.
- Human check: read the four items, then reorder, reword or delete them. All
  four can be taken by the agent as they stand.
