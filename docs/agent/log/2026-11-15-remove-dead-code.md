# 2026-11-15: Q6, dead code removed

- Deleted `BeerParty/Features/Auth/AuthOTP.swift`. Its one function,
  `sendMagicLink`, was called from nowhere; sign-in is Google only
  (`LoginView`). The project uses folder-synced groups, so no project file edit
  was needed.
- Removed `import SwiftData` from `BeerPartyApp.swift`. Nothing in the app uses
  SwiftData.
- Removed the `mapRegion` state from `LobbyView`. It existed only to carry a
  San Francisco centre that was overwritten before use; the one place that used
  it now builds the region directly. Same centre, same zoom, no visible change.
- Not done, split into a new item Q6b: the `bac_etimate` fallback, which waits
  for S1 to confirm the column name.
- Left alone: `mapPosition` still starts on San Francisco until the first member
  location arrives. A map needs some starting position; a better one belongs to
  U3.
- Verified: build and unit tests in CI (a deleted file or import that was still
  needed would fail the build).
- Human check on a device: open a lobby where someone shares a location; the
  map still centres on them the first time it loads.
