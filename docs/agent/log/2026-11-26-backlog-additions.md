# 2026-11-26: five new backlog items

- No `agent` pull request was open at the start (#51 to #60 are all merged),
  so there was nothing to repair. No `agent-queue` issue is open.
- This run took every backlog item that was free: B22 (#62), B23 (#63), B24
  (#64), Q9 (#65) and Q2 part 10 (#66). Everything else is tagged
  `needs-owner` or waits for S1 or for the `lobby_events` migrations to be
  applied, so this sixth pull request adds new items instead. No app code
  changed here.
- Added, each with the place in the code it comes from:
  - **S10**: after "Made it home" the phone keeps sharing its position, so
    the pin the whole lobby sees marks the member's home.
  - **B25**: nickname, lobby name, drink name and motion destination can be
    any length.
  - **B26**: "Made it home" can be sent again and again, and every phone
    shows the line each time.
  - **Q10**: a lobby that closed days ago is still polled every 30 seconds
    (three requests) while its screen is open.
  - **U13**: a forgotten drink can only be added as "just now"; a "When"
    choice in the "Add Drink" form.
- Also in `BACKLOG.md`: U12 is ticked (its pull request #59 is merged; the
  box was left open there on purpose), and B5 step 2 now says that the
  second migration file is merged.
- Looked at and not added:
  - A member who leaves the lobby keeps their votes in `motion_votes`, so a
    motion can count as "everyone has voted" one vote early. Rare, and the
    tally moves to the server with S4.
  - Volumes are typed in millilitres and BAC is shown in per mille also on a
    US phone, where ounces and percent are usual. That is a product
    decision more than a bug; tell the agent if you want it as an item.
  - The two open questions from 2026-11-24 (the Live Activity keeps the
    first lobby's name; the unread `bac_estimate` write) are still open.
- These come from reading the code only; none was reproduced on a device.
- Human check: read the five items, then reorder, reword or delete them. All
  five can be taken by the agent as they stand; S10 and B26 touch the same
  button and should not be open at the same time.
