# 2026-11-21: B12, location sharing starts the first time permission is given

- The first time a user switched on "Share my location", iOS asked for permission
  and the app stopped there: `LocationTrackingService.startTracking` returned
  without remembering that tracking was wanted, so the permission callback did
  nothing after "Allow". No pin appeared until the toggle was switched off and on.
- The service now remembers that tracking is wanted (`wantsTracking`) from
  `startTracking` until `stopTracking`, and the permission callback starts or
  stops updates from that. The decision for each permission status ("ask",
  "start", "stop") is a small function, `LocationTrackingPlan.step`.
- When permission is refused, the service stops updates but still remembers the
  wish, so sharing begins if the user later allows location in Settings while the
  toggle is on.
- When the toggle is on and permission is refused or restricted, the lobby screen
  shows one line under the two toggles: "Location access is off for BeerParty.
  Allow it in the Settings app (BeerParty > Location) to share your location."
- Not changed: when "Always" permission is asked for (only from the toggle, as
  before), accuracy, the distance filter, and everything that clears stored
  coordinates.
- Unit tests in `LocationTrackingPlanTests`: every permission status with sharing
  on and off, and when the Settings line shows.
- Verified: build and unit tests in CI. Not tested on a device; the permission
  prompt cannot be exercised in CI.
- Human check, on a phone where BeerParty has never asked for location (delete
  and reinstall the app, or reset Location & Privacy): (1) open a lobby, switch
  on "Share my location in foreground", tap "Allow While Using App": your pin
  appears on the map within a short time, without touching the toggle again.
  (2) Reinstall, switch the toggle on and tap "Don't Allow": the line about
  Settings appears under the toggles. (3) Allow location for BeerParty in
  Settings and return to the lobby: the line goes away and your pin appears.
- Backlog: B12 is one of the items proposed in pull request #35, which is not
  merged yet, so there is no line on `main` to tick and `BACKLOG.md` is not
  changed here (adding the line would conflict with #35). Once #35 is merged, a
  later run ticks B12.
