# 2026-11-24: five new backlog items

- Every pull request from 2026-11-23 is merged (#43 to #48) and no `agent` pull
  request was open at the start, so no repairs were needed. No `agent-queue`
  issue is open. The only item the agent could take today was the next part of
  Q2 (one part per run, pull request #49); everything else is tagged
  `needs-owner` or waits for S1 or for the `lobby_events` migration to be
  applied. The rest of the run went to reading the code for new work. No app
  code changed in this pull request.
- Nothing needed ticking: B15 to B18, U10 and Q2 part 7 were ticked by their own
  pull requests.
- Added, each with the place in the code it comes from:
  - **B19**: the graph of a past lobby runs all the way to today (the BAC
    simulation always ends at the current time, also for a lobby closed days
    ago).
  - **B20**: a lobby the host deleted stays open on everyone else's phone, and
    the Lock Screen buttons keep trying ("lobby not found" is ignored as a
    passing failure).
  - **B21**: a member's changed body values or nickname never reach the other
    phones (the member list is reloaded only when somebody joins or leaves).
    This matters more since B15, which made the body values real.
  - **U11**: the weight field always starts in pounds. Probably the most
    important one for European users: typing kilograms into it gives a BAC
    that is clearly too high, now that the weight is used.
  - **U12**: "Made it home" stops working at closing time, just before people
    go home.
- Looked at and not added:
  - The Lock Screen Live Activity keeps the name of the lobby it was first
    started in: turning quick add on in a second lobby sends the drinks to the
    second lobby but the Lock Screen still shows the first lobby's name
    (`upsertActivity` updates the running activity and never replaces it). Only
    matters for someone in two open lobbies on one evening.
  - The app writes each member's BAC to `member_state.bac_estimate` every five
    minutes (`syncCurrentUserBACIfNeeded`), and nothing in the app reads it;
    every phone works the BAC out itself from the drinks. Removing the write
    would store less about users and remove one error message, but the owners
    may have plans for the column.
  Tell the agent if you want either as an item.
- These come from reading the code only; none was reproduced on a device. B19
  and U11 follow directly from the code. B20 depends on what the database
  returns for a deleted lobby (its rules are not in the repo, S1), which is why
  the item says the member list "can" empty.
- Human check: read the five items, then reorder, reword or delete them. All
  five can be taken by the agent as they stand; U12 also adds a migration file
  for an owner to apply. A quick look at U11 on a device: "Edit Profile" shows
  "Weight (lbs)" on a phone set to a European region. For B19: open a lobby
  from a few days ago and look at the graph.
