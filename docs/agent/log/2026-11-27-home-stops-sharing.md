# 2026-11-27: S10, "Made it home" ends location sharing

- Before: `sendMadeItHome` wrote the message and nothing else. With location
  sharing on, the phone went on uploading its position, so the pin the whole
  lobby sees marked the member's home until they switched sharing off
  themselves or the five hours after closing were over.
- Now, in `LobbyView`: after a "Made it home" that was sent successfully with
  sharing on, the phone stops tracking, removes the stored position
  (`endLocationSharing()`, as when leaving the screen) and takes the own pin
  off the map at once. The status line says "... is safely at the fortress of
  dreams. Your location is no longer shared." The other phones show the first
  sentence only, as before, and drop the pin at their next 20-second refresh.
- It stays off for the rest of this visit to the lobby screen: the new flag
  `isSharingPausedAfterHome` is checked wherever a position is uploaded or
  tracking is started (new positions, the two-minute resend, pull-to-refresh).
  If clearing the stored position fails (no signal), the 20-second timer
  tries again.
- The saved profile setting is not changed, so the toggle still says "on". A
  line under it says "Not shared since you made it home. Switch off and on to
  share again.", and doing that shares again. Leaving the lobby screen and
  coming back also shares again (the setting is still on); say so if "Made it
  home" should hold for the whole lobby instead, which needs somewhere to
  remember it (B26 asks for the same memory for the button).
- The rules (does sending end sharing, the sender's sentence, when the hint
  shows) are `MadeItHomeSharing`, a plain type with tests.
- Tests: `MadeItHomeSharingTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, two phones in one lobby, sharing on for phone A:
  - A's pin is on B's map. A taps "Made it home": A sees the longer sentence,
    A's pin is gone from A's map at once and from B's within about half a
    minute, and the hint is shown under A's toggle.
  - A walks or waits three minutes, pulls to refresh: still no pin.
  - A switches the toggle off and on: the pin is back.
  - With sharing off, "Made it home" shows the short sentence as before.
- Backlog: S10 ticked (checkbox only). B26 touches the same button and is
  left for another day.
