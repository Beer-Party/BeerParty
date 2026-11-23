# 2026-11-23: B15, BAC uses each member's own weight, age and gender

- The bug: `ensureCurrentUserBACParams` asked the `profiles` table for four
  columns and decoded the answer as `UserProfile`, which needs two more. Decoding
  failed every time, so every member was saved with the fallback values (body
  water 40, elimination 0.14) and everyone got the same BAC from the same drinks.
- The answer is now decoded into `BACProfileFields`, which has only those four
  fields. The formulas moved unchanged into `BACBodyParameters.derive`
  (`BeerParty/Features/Lobby/BACBodyParameters.swift`).
- Rows saved earlier held the fallback and were never written again. Now, each
  time a lobby is opened, the user's own row is rewritten when it differs from
  what the profile gives (`BACBodyParameters.needsSaving`). So existing lobbies
  correct themselves once each member opens them, and a changed weight counts in
  lobbies joined earlier.
- If the profile cannot be read (offline), a row that is already saved is left
  alone; only a member with no row gets the fallback.
- Expect the numbers to move: BAC values and graph lines in existing lobbies
  change the first time each member opens the lobby after updating the app
  (closed lobbies too). The other phones pick the new values up when they next
  load the lobby or when the member list changes.
- Unit tests in `BACBodyParametersTests`: decoding exactly the JSON the query
  returns, the three formulas, "female" not being read as "male", clamping, the
  fallback, and when a saved row is rewritten.
- Verified: build and unit tests in CI. Not tested on a device and not against
  the database (the project is paused, and the agent does not write to it).
- Human check: two members with clearly different weight or gender log the same
  drink in one lobby; their BAC values now differ. In the Supabase table
  `lobby_member_bac_params` the two rows no longer both hold 40 and 0.14.
- Not known from the repo (S1): whether the table's rules let a member update
  their own row. The app already upserts into it, and a refused write is
  ignored when a lobby loads, so the worst case is the old behaviour.
- Backlog: ticks B15.
