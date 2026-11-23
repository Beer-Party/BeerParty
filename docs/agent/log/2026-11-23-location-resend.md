# 2026-11-23: B16, a member who stays put stays on the map

- The bug: iOS reports a new position only after 25 metres of movement
  (`distanceFilter = 25`) and the app uploaded a position only then. The map
  hides pins older than five minutes, so a friend sitting in the bar vanished
  from the map until they walked.
- While sharing is on, the 20-second location timer in `LobbyView` now uploads
  the last known position again when the last upload is two minutes old or more
  (`resendOwnLocationIfDue`). The decision is `LocationResend.isDue`
  (`BeerParty/Core/Services/LocationResend.swift`).
- A position that was never saved (the first upload failed) is also sent on the
  next tick. A failed re-send shows no message and is tried again 20 seconds
  later; a failed upload of a new position still shows its message.
- `LocationTrackingService.stopTracking` now forgets the last position, so a
  position from before sharing was switched off cannot be sent after it is
  switched on again.
- Privacy: nothing is sent that was not sent before, only the same position
  with a new time, and only while the sharing toggle is on and the lobby is
  live. Leaving the screen or switching sharing off still clears it (S5).
- Cost: one small request about every two minutes per sharing member, only
  while the lobby screen's timers run.
- Worth knowing: the service has `pausesLocationUpdatesAutomatically = true`.
  If iOS pauses updates for a phone lying still and the person later walks off,
  the pin stays at the old place until iOS reports again. Before this change
  the pin would have vanished instead. Say so if you would rather cap how long
  an unchanged position is re-sent.
- Unit tests in `LocationResendTests`: recent upload, two minutes and older,
  never uploaded, sharing off, no known position, clock set back.
- Verified: build and unit tests in CI. Location cannot be tested in CI.
- Human check, with two phones in one lobby and sharing on: leave phone A lying
  still with the lobby screen open for ten minutes. Its pin stays on phone B's
  map the whole time. Switch sharing off on A: the pin goes within about 20
  seconds and does not come back. Switch it on again: the pin returns at the
  current place.
- Backlog: ticks B16.
