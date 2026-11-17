# 2026-11-17: five new backlog items

- After today's five pull requests, every remaining backlog item is either tagged
  `needs-owner` or waits for one that is (S1, or applying the `lobby_events`
  migration for B5 step 3). Q2 continues one part per run. So this run read the
  code for new work and added five items. No app code changed in this PR.
- Added, each with the place in the code it comes from:
  - **B6**: a decimal comma is rejected in drink volume, ABV and profile weight
    (`Double(text)` on text from the decimal keypad).
  - **B7**: other members' edited or deleted drinks never reach other phones, and
    drinks from a phone with a slow clock are skipped (`fetchNewDrinks` filters on
    `consumed_at` later than the newest drink shown).
  - **B8**: two members with the same nickname are drawn as one line (the chart
    series and `latestPointByMember` are keyed by nickname).
  - **B9**: no upper limit on ABV or volume.
  - **S7** (`needs-owner`, after S1): no in-app account deletion.
- These come from reading the code only; none was reproduced on a device.
- Human check: read the five items, then reorder, reword or delete them. B6 to B9
  can be taken by the agent as they stand. S7 needs your decision on what
  "delete my account" removes.
