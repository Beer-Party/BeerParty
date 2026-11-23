# 2026-11-22: five new backlog items, and yesterday's items ticked

- Every pull request from 2026-11-20 and 2026-11-21 is merged (#34 to #40), so no
  repairs were needed and no `agent` pull request was open at the start. The
  only item the agent could take today was the next part of Q2 (one part per
  run, pull request #41); everything else is tagged `needs-owner` or waits for S1
  or for the `lobby_events` migration to be applied. The rest of the run went to
  reading the code for new work. No app code changed in this pull request.
- Ticked, because their pull requests are merged: **B12** (#36), **B13** (#37),
  **B14** (#39) and **U9** (#38). Yesterday's pull requests could not tick them,
  because the lines were not on `main` yet. The Q2 "Part 5" line (#40) is added
  by today's #41, next to its own "Part 6" line, so the two pull requests do not
  touch the same lines.
- Added, each with the place in the code it comes from:
  - **B15**: everyone's BAC uses the same fallback body values
    (`ensureCurrentUserBACParams` decodes a four-column answer as `UserProfile`,
    which needs two more columns, so decoding always fails). This looks like the
    most important one: weight and gender from the profile are never used.
  - **B16**: a member who stays in one place disappears from the map after five
    minutes (a position is uploaded only after 25 metres of movement; pins older
    than five minutes are hidden).
  - **B17**: a motion "in 5 min" is announced up to five minutes late (voting
    always stays open 10 minutes).
  - **B18**: the widget's custom button probably gets an empty name (the name is
    read after the form has been emptied). Seen while moving that code in #41.
  - **U10**: invite codes only match in exactly the same capital and small
    letters.
- Looked at and not added: `notifyMotionArrivalIfNeeded` marks a motion as
  announced without checking that nobody else has just done so, so two phones
  that poll in the same second can both write the "motion due" row. The only
  effect is the same status line twice, and S4 (deciding motions on the server)
  replaces that code. Also not added: age and weight in the profile have no
  upper limits (the BAC maths clamps them). Tell the agent if you want either
  as an item.
- These come from reading the code only; none was reproduced on a device. B15
  follows from how Swift decodes a type with required fields; B18 depends on
  SwiftUI returning the emptied text at that point, which is why its item says
  to check on a device first.
- Human check: read the five items, then reorder, reword or delete them. All
  five can be taken by the agent as they stand. A quick look at B15 on a device:
  two members with clearly different weights log the same drink and show the
  same BAC.
