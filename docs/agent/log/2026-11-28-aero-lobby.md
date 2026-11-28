# 2026-11-28: issue #71, second step of the new look (the lobby screen)

- Issue #71 asks for a more appealing, professional look (Frutiger Aero,
  Oura). #77 set the direction on the hub and was merged, so this run carries
  it to the screen people look at most: the lobby.
- New in `AppVisualTheme.swift`:
  - `.aeroRows()` and `AeroRowBackground`: the rows of a form section as
    frosted glass, with quiet lines between them.
  - `AeroStatusPill`: the green "ACTIVE" capsule of the hub as a shared piece,
    with a muted grey form for "CLOSED".
  - `AeroTheme.chartPalette`, `chartGrid`, `chartLabel`: eight line colours
    led by aqua and green, and grid and label tones for a chart on dark glass.
- `LobbyView`:
  - The form's grey background is gone; `AeroBackground` shows behind it and
    every section is glass. The whole screen uses the rounded typeface,
    section headings included.
  - Header: the lobby name in the rounded typeface, and "Status: Active" /
    "Status: Closed" as an "ACTIVE" / "CLOSED" pill (VoiceOver still reads
    "Status: Active").
  - Graph: a darker plot area, soft grid lines, readable axis labels, and the
    new line colours. With more than eight members the colours start again;
    the name at the end of each line still tells them apart.
  - Map: rounder corners and a light edge.
  - Active motion: "Aye" is the glossy main button, "Neigh" a glass button
    (they were system green and orange).
  - Lobby actions: glass tinted in the action's colour with white text
    (the text itself used to be blue, purple, red or orange, which was hard
    to read), and visibly dimmed when they cannot be used.
  - Quick-add emoji buttons: a soft aqua glow.
- `LiveBACSection`: the bars and the "You" tag are aqua and green instead of
  yellow and orange.
- `LobbyStatusBanner`: an aqua upper edge.
- Not touched: the text fields of "Add Drink" and "Motions" and the "Create
  Motion" button (other pull requests of today edit those files), the "Edit
  Drink" sheet, login, profile setup, the join and make sheets, the Lock
  Screen widget. Suggested order for the next runs: login and profile, then
  the two sheets and the widget (and "Create Motion", still indigo).
- No logic changed, so no new unit tests.
- Verified: build and unit tests in CI. This workspace cannot run the app,
  so nobody has seen this on a screen yet. Please look before merging.
- Human check on a device:
  - Lobby screen, open and closed lobby: every section is a glass pane on the
    blue background, text is readable in all of them, nothing is left grey.
  - Header: the "ACTIVE" / "CLOSED" pill; "Reveal invite code" and "Share
    invite code" still work.
  - Graph with three or more members: the lines are told apart, the axis
    labels are readable, long press and pinch still work.
  - Active motion: "Aye" and "Neigh" each react to their own tap.
  - Lobby actions: all buttons readable; "Made it home" looks dimmed when it
    cannot be sent.
  - The emoji buttons at the top still sit above the form and work.
  - Settings, Accessibility: with "Reduce Transparency" on, and with a larger
    text size, the rows are still readable and nothing is cut off.
- Backlog: nothing to tick; the work is tracked in issue #71.
