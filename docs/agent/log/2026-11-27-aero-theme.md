# 2026-11-27: issue #71, a first step towards the new look (theme and hub)

- Asked for in issue #71 by an owner: more appealing and professional,
  inspired by Frutiger Aero and apps like Oura. That is a job for several
  pull requests; this one sets the direction on one screen, so you can say
  yes or no to it before it spreads.
- The direction: "deep water with light in it". Dark and calm with a lot of
  room, as in Oura; glass panes with a bright upper edge, gloss on the main
  button, aqua and fresh green, as in Frutiger Aero. The app stays dark, so
  the screens that are not restyled yet still fit.
- New in `AppVisualTheme.swift`:
  - `AeroTheme`: the colours (dark blue tones, aqua accent, green for
    "active").
  - `AeroBackground`: the screen background, a dark blue gradient with three
    soft lights. Nothing moves.
  - `.aeroCard()`: a frosted glass pane with gloss, a light edge and a soft
    shadow.
  - `AeroGlossButtonStyle`: the glossy main button; greyed when disabled.
- `BeerPartyApp`: the black background and the rainbow frame around the whole
  app are replaced by `AeroBackground`, and the app's accent colour (switches,
  links, system buttons) is aqua on every screen. The rainbow frame's code is
  removed; say so if you want it back, it is one revert.
- `PreLobbyView` (the hub): new background, both cards are glass panes,
  "Join Lobby" is the glossy main button and "Make Lobby" a glass button,
  the active lobby glows aqua instead of yellow with a green "ACTIVE" pill,
  headings in the rounded typeface.
- Not touched: login, profile setup, the lobby screen, the two sheets and the
  Lock Screen widget. They keep their look apart from the accent colour and
  the missing rainbow frame. Suggested order for the next runs: lobby screen
  (sections as glass panes, graph colours), then login and profile, then the
  sheets and the widget.
- No logic changed, so no new unit tests.
- Verified: build and unit tests in CI. This workspace cannot run the app,
  so nobody has seen this on a screen yet. Please look before merging.
- Human check on a device:
  - Hub: text is readable on both cards and on the "Join Lobby" button; the
    active lobby stands out; with no lobbies the empty state looks right.
  - The screen edges: nothing is cut off where the rainbow frame used to be
    (top bar with avatar and "Sign Out", bottom of the list).
  - Lobby screen, login, profile: still usable; switches are aqua.
  - With "Reduce Transparency" on (Settings, Accessibility), the cards are
    still readable.
- Backlog: nothing to tick; the work is tracked in issue #71.
