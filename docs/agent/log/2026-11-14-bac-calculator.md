# 2026-11-14: Q1, BAC maths moved out of LobbyView and tested

- The BAC model (absorption, elimination, per-member timeline, lobby snapshot)
  moved from private code at the bottom of `LobbyView.swift` into
  `BeerParty/Features/Lobby/BACCalculator.swift`. The code was moved, not
  rewritten: same formulas, same constants, same results. `LobbyView` shrinks by
  about 150 lines and calls `BACCalculator.snapshot(...)`.
- Added `BACCalculatorTests` (13 tests): absorption window, parameter defaults
  and clamping, one beer after one hour checked against a hand calculation, BAC
  back to zero by morning, water, body-water effect, snapshot ranking.
- Verified: build and tests in CI. The expected numbers in the tests were also
  checked against a separate re-implementation of the formulas.
- Human check on a device: open a lobby with drinks. The chart, the ranking and
  the buddy comparison should look exactly as before.
- Noticed, not changed: the values behave like per-mille (two beers in an hour
  gives about 0.2), while the UI and `member_state` call it BAC. Worth an owner
  deciding which unit the app shows. Q4 (do not re-simulate on every render) is
  easier now and can follow once this is merged.
