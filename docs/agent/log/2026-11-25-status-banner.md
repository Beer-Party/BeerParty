# 2026-11-25: the lobby's status line becomes a banner at the bottom of the screen

- One of five UI changes an owner asked for in the agent chat on 2026-11-25
  (a one-off request, not a backlog item, so `BACKLOG.md` is not changed).
- Before: messages such as "Added Beer.", "Tap 'Confirm Closing Time' within 8
  seconds ..." and every error were the last row of the lobby form. The form is
  several screens long and the buttons that cause the messages are at the top
  (quick add) or in the middle, so the message was normally off screen. Tapping
  🍺 gave no visible answer.
- Now: the message is shown in a banner fixed to the bottom of the screen
  (`LobbyStatusBanner`, in `BeerParty/Features/Lobby/Views/`), wherever the form
  is scrolled to. It slides in, and has an ✕ to put it away. A new message
  replaces the old one, as before. The row at the end of the form is gone.
- The banner does not hide by itself: some messages ask for a second tap within
  8 seconds and errors should stay readable. Say so if you want short
  confirmations ("Added Beer.") to fade after a few seconds.
- No unit tests: view code only, the messages themselves are unchanged.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check, in an open lobby:
  - Tap 🍺: "Added Beer." appears at the bottom without scrolling. Tap ✕: it
    goes away.
  - Scroll to the end of the form: the last section ("Drink History") is fully
    visible above the banner, not hidden behind it.
  - With the keyboard open in "Drink name", add a drink: check where the banner
    sits (it should be above the keyboard, not under it).
  - "Closing Time" as creator: the "Tap 'Confirm Closing Time' ..." line shows
    in the banner and the button is still reachable.
