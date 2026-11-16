# 2026-11-16: Q3, member avatars in one query

- `fetchLobbyRoster` (used by `fetchLobbyAnalytics`) and `fetchMemberLocations`
  each ran one `profiles` request per lobby member; the second one repeats every
  20 seconds while the map is open. Both now call one helper,
  `fetchProfilePicPaths(userIDs:)`, which asks for all members' avatar paths in a
  single request (`id in (...)`).
- Same columns as before (`id, profile_pic_path`), so no database or policy
  change is needed. If the request fails the lobby loads without avatars, as it
  did before when the per-member requests failed.
- `ProfilePhotoRow` is no longer private so the row-to-dictionary step can be
  unit tested (`ProfilePhotoRowTests`).
- Only `LobbyBackendService.swift` changed in the app; `LobbyView.swift` is
  untouched, so this does not conflict with #7 or #11.
- Verified: build and unit tests in CI. The request itself is not exercised by
  CI (no backend there). Not tested on a device.
- Human check: open a lobby with two or more members who have profile pictures.
  The avatars show in the member list and on the map pins, as before.
