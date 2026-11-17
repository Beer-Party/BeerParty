# 2026-11-17: U3, the map frames every member and has a re-centre button

- The member map used to centre once, on whichever member the server returned
  first, with a fixed zoom. Members further away were off screen.
- The first time locations arrive, the map now zooms to a region that contains
  every member with a fresh location (updated in the last 5 minutes, the same rule
  the pins use), with some room around the outermost pins.
- A round button with a target icon in the top-right corner of the map does the
  same again on demand, after the user has panned or when someone has moved.
- The map does not move by itself after the first framing, so it never jumps while
  someone is looking at it.
- The region is worked out by `MemberMapFraming.region(for:)`. It never zooms in
  closer than about 2 km, so one member, or several at the same bar, still show
  some surroundings. Before, a single member got a fixed, much wider view (0.12°).
- Not handled: members on both sides of the 180° meridian (the map then shows the
  long way round).
- Unit tests in `MemberMapFramingTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, with two phones sharing location in one lobby: (1) open the lobby:
  both pins are visible without panning. (2) Pan away, tap the target button: the
  map animates back to both pins. (3) With one phone only: the pin is centred with
  a neighbourhood-sized view. (4) Tapping the button does not trigger anything else
  in the row, and VoiceOver reads it as "Re-centre map on members".
