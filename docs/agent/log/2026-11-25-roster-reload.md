# 2026-11-25: B21, members' changed body values and nicknames reach the other phones

- Before: the member list and the BAC values were reloaded only when the set of
  member ids changed (`LobbyRoster.needsReload`). A member whose weight changed
  (since B15 that rewrites their row in `lobby_member_bac_params`) or who
  joined again under another nickname kept the old values and the old name on
  everybody else's phone until pull-to-refresh. A phone that read the list
  between a new member's `lobby_members` row and their BAC row used the
  fallback values for that member for the rest of the night.
- Now, in `LobbyView`:
  - Every two minutes, together with the full drink reload, the roster
    (members, nicknames, photos, BAC values) is read again
    (`reloadRosterIfChanged`). The screen is only updated when something
    differs (`LobbyRoster.differs`), so the BAC graph is not worked out again
    for nothing.
  - The 30-second check also reloads at once when a shown member has no BAC
    values (`LobbyRoster.hasMemberWithoutBACValues`).
- Cost: one more roster read (three small requests) every two minutes while
  the lobby screen is open. If a member never gets a BAC row (their profile
  could not be read and saving the fallback failed too), the 30-second check
  reloads the roster every time; that is the same three requests every 30
  seconds and stops as soon as the row exists.
- Tests: new cases in `LobbyRosterTests` (other order is no change; nickname,
  body values, photo, a joining member and values arriving later are a
  change; a member without values is noticed).
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, two phones A and B in one lobby, both with drinks:
  - On B, "Edit Profile" and change the weight a lot. Open the lobby on B once
    (that rewrites B's values). Within about two minutes A's "Live BAC" value
    for B changes, without pull-to-refresh.
  - B leaves nothing, but joins the same lobby again with the invite code
    under another nickname: within about two minutes A shows the new name.
- Other open pull requests: #57 (B20) also changes `LobbyView.swift` and
  `LobbyBackendService.swift`, in other places (checked against its diff).
- Backlog: B21 ticked (checkbox only).
