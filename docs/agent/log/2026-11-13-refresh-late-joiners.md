# 2026-11-13: B3, people who join later now appear

- The lobby's 30-second refresh now also asks for the lobby's member ids (one
  small request). If the set differs from the members on screen, the member list
  and BAC parameters are reloaded. Someone who joins or leaves shows up within
  about 30 seconds, without pull-to-refresh.
- The member check runs before the motion refresh, so motion tallies use the
  current member count.
- `fetchLobbyAnalytics` was split: the member and BAC-parameter part is now
  `fetchLobbyRoster`, reused by the refresh. Same queries as before, no behaviour
  change on first load.
- A new member's drinks were already being fetched (the drink refresh is per
  lobby); they were just not drawn because the member was unknown.
- Verified: unit tests for the "has the member set changed" rule. Build and tests:
  CI. Not tested against a real lobby.
- Human check on a device: two phones. Phone A sits in the lobby; phone B joins
  with the invite code. Within about 30 seconds B appears on A, B's drinks show on
  the chart, and a motion needs both votes. B leaves: B disappears from A.
- Not done here: each reload still fetches avatars one request per member (Q3).
