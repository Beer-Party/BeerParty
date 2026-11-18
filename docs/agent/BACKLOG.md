# Backlog

Ranked. The agent takes the first unchecked item that is not `needs-owner`.
Owners: reorder, delete or add freely. `needs-owner` means it is blocked on a
decision or an action only an owner can take.

## 0. Migrations waiting for an owner to apply

Files in `supabase/migrations/` that are merged but not yet run against the live
project. The agent never applies them. Owner: run the file in the Supabase SQL
editor, then tick the line.

- [ ] `needs-owner`: apply `20261112110000_fix_close_expired_motions_tally.sql`
  (S3).
- [ ] `needs-owner`: apply `20261113110000_clear_stale_member_locations.sql` (S5),
  then run the optional pg_cron block at the bottom of that file once so the expiry
  runs on a schedule.

## 1. Privacy and security

- [ ] **S1 `needs-owner`: put the database schema in the repo.** Only the motions
  tables are in git (`supabase_motions.sql`). `lobbies`, `lobby_members`,
  `member_state`, `drinks`, `profiles`, `lobby_member_bac_params` and all their RLS
  policies exist only in the Supabase project, which is currently paused. Owner
  resumes the project; the agent then dumps the schema into `supabase/migrations/`.
- [ ] **S2 `needs-owner` (after S1): joining a lobby should not require every
  signed-in user to be able to read the `lobbies` table.** `joinLobby` looks a lobby
  up by `invite_code` before the user is a member, and `MakeLobbyView` checks code
  uniqueness the same way, so the select policy must let non-members read lobby rows,
  invite codes included. Anyone with an account could then list codes, join, and see
  members' live locations. Fix: a `join_lobby(code, nickname)` security-definer
  function, lobby rows readable by members only, generated codes instead of
  user-chosen ones (minimum is 4 characters today).
- [x] **S3: `close_expired_motions` passes motions it should fail.** The query joins
  votes and members in one pass, so the aye count is multiplied by the member count:
  one aye in a five-person lobby counts as 5/5. Fix with separate subqueries
  (migration file only). Done 2026-11-12 in
  `supabase/migrations/20261112110000_fix_close_expired_motions_tally.sql`.
- [ ] **S4 (after S1): decide motion results on the server.** Today whichever phone
  polls first computes `passed` and writes it, using a member list that can be stale,
  and the update policy lets any member write any column. Move the tally into a
  function and narrow the policy.
- [x] **S5: stop keeping last-known locations.** `member_state.lat/lng` is cleared
  only when the user turns sharing off. Leaving the lobby view, the lobby closing or
  the 5-hour tail ending all leave the last coordinates in the table. Clear on those
  events in the client, and add a server-side expiry migration. Done 2026-11-13
  (client clear plus
  `supabase/migrations/20261113110000_clear_stale_member_locations.sql`).
- [ ] **S6 `needs-owner` (after S1): check that other members cannot read
  `profiles.weight`, `age`, `gender`.** The client reads other members'
  `profile_pic_path` from `profiles`, so the select policy allows cross-user reads
  of at least that table.
- [ ] **S7 `needs-owner` (after S1): there is no way to delete an account.** The
  app creates accounts (Google sign-in plus a profile with weight, age, gender and
  a photo) but only offers "Sign out". App Store review guideline 5.1.1(v) expects
  in-app account deletion, and users cannot remove their data themselves. Needs an
  owner decision on what is deleted (profile, photo, drinks, memberships, lobbies
  the user created) and a server-side function, since the app cannot delete an
  auth user with the anon key. Found 2026-11-17.
- [ ] **S8: signing out leaves the Lock Screen quick-add signed in.**
  `PreLobbyView.signOut` only calls `supabase.auth.signOut()`. The quick-add
  context in the shared app group (`lobby.quickadd.context`, which holds the
  access token) and the Live Activity are removed only by lobby-screen actions
  (leave, close, delete, switching the toggle off). After sign-out the Lock Screen
  buttons therefore keep adding drinks and votes as the previous user until the
  token expires (up to an hour), and the token stays on disk. Call
  `LobbyLiveActivityService.endContext()` on sign-out and on the signed-out auth
  event. Found 2026-11-18.

## 2. Bugs

- [x] **B1: token refresh probably throws the user out of the lobby.**
  `AuthViewModel.refreshProfileState` sets `profileState = .unknown` on every auth
  event, including the hourly token refresh. `RootView` swaps to a spinner, which
  tears down `PreLobbyView` and the lobby pushed on top of it. Keep `.complete`
  while re-checking. Needs a device check. Done 2026-11-13; device check
  still open.
- [x] **B2: a failed profile check sends existing users to profile setup.** Any
  error, offline included, is treated as "no profile". Distinguish "no row" from
  "request failed". Done 2026-11-16; device check still open.
- [x] **B3: people who join later do not appear.** `members` is loaded once; the
  30-second refresh only fetches drinks. New members (and their drinks) show up only
  after pull-to-refresh, and motion tallies use the stale count. Done 2026-11-13.
- [x] **B4: Lock Screen quick-add stops working after about an hour.** The access
  token is copied into the app group once when the lobby loads and never refreshed,
  so it expires. Refresh it on the live timer and on auth events. Done 2026-11-14
  while the lobby screen is open; a phone locked for over an hour still needs an
  owner decision (see `docs/agent/log/2026-11-14-refresh-lockscreen-token.md`).
- [ ] **B5: system events are stored as fake drinks.** "Made it home", "lobby
  closed" and "motion due" are rows in `drinks` with magic name prefixes; any member
  can forge them and a real drink name starting with `__home__:` vanishes. Move to a
  `lobby_events` table (migration + client, split over several PRs).
  - [x] Step 1, 2026-11-15: the table and its rules, as
    `supabase/migrations/20261115110000_create_lobby_events.sql`.
  - [ ] Step 2 `needs-owner`: apply that file in the Supabase SQL editor.
  - [ ] Step 3 (after step 2): the app writes and reads `lobby_events`, and still
    reads the old prefixed rows so phones on the old version keep working.
  - [ ] Step 4 (after step 3 has shipped): stop reading the prefixed rows and
    delete them (migration).
- [ ] **B6: a decimal comma is rejected.** `LobbyView` parses volume and ABV with
  `Double(text)` (add form and edit sheet), and `ProfileSetupView` does the same
  for weight. The decimal keypad shows a comma in most European regions, and
  `Double("4,7")` is nil, so "Add Drink" and "Save" stay disabled with no
  explanation. Parse both separators in one shared helper, with unit tests. Found
  2026-11-17.
- [ ] **B7: other members' edited and deleted drinks never arrive, and some new
  ones are missed.** The 30-second refresh asks only for drinks with `consumed_at`
  later than the newest one already shown (`fetchNewDrinks`). An edit or a delete
  changes no such row, so every other phone keeps the old drink in its BAC and
  graph until pull-to-refresh. `consumed_at` is also the adding phone's own clock,
  so a drink from a phone whose clock is behind falls before the cursor and is
  skipped. Reload the full drink list on a slower cycle (or compare ids), with the
  merge as a tested pure function. Found 2026-11-17.
- [ ] **B8: two members with the same nickname share one line on the graph.** The
  chart groups and colours by `point.nickname`, and `latestPointByMember` is keyed
  by nickname; nothing stops two members from choosing the same one. Their points
  are drawn as a single zig-zag line with one label. Key the series by user id and
  keep the nickname for the label only. Found 2026-11-17.
- [ ] **B9: drink input has no upper limits.** Volume only has to be above 0 and
  ABV only 0 or more, so a slip such as ABV 400 or 33000 ml is saved, produces an
  absurd BAC and is synced to the whole lobby. Reject ABV above 100 and volume
  above a sane maximum (for example 2000 ml) in the add form, the edit sheet and
  `updateDrink`, with a short message; add a check constraint as a migration file
  once S1 is done. Found 2026-11-17.
- [ ] **B9b (after S1): database check constraint for drink volume and ABV.**
  Split out of B9, whose app-side limits are in the pull request of 2026-11-18.
  A migration file adding `check (volume_ml >= 0 and volume_ml <= 2000 and abv >= 0
  and abv <= 100)` to `drinks` (system-event rows use 0 and 0), so a modified
  client cannot save absurd values either.
- [ ] **B10: a failed "Make Lobby" leaves a half-made lobby behind.**
  `MakeLobbyView.createLobby` sends four separate requests: insert into `lobbies`,
  then `lobby_members`, `member_state` and the BAC parameters. If the second one
  fails (connection drops), the lobby row exists with no members: it appears in
  nobody's list, and trying again says "That invite code is already in use". Move
  the steps into one function on `LobbyBackendService` that deletes the lobby row
  again when a later step fails, with the order of steps unit-tested; the proper
  fix is a single `create_lobby` database function after S1. Found 2026-11-18.
- [ ] **B11: Lock Screen quick-add still adds drinks after the lobby is closed.**
  The app's `insertDrink` refuses when the lobby is closed, but the widget's
  `QuickAddDrinkIntent` posts straight to `drinks` with no such check. The Live
  Activity is ended only if this phone has the lobby screen open when the lobby
  closes (`refreshLobbyActivityStatus`), so a locked phone keeps its buttons and
  its drinks land in a closed lobby (also after the 24-hour auto-close). In the
  intent, read `lobbies.is_active` first; when closed, end the activity and say
  so. A database rule belongs with S1. Found 2026-11-18.

## 3. Code health

- [x] **Q1: move the BAC maths out of `LobbyView` into a plain type with unit
  tests.** It is private view code today, and the test target has no real tests.
  Done 2026-11-14: `BACCalculator`.
- [ ] **Q2: split `LobbyView.swift` (1,915 lines, about 60 `@State` properties)**
  into a view model plus one view per section. Several PRs.
  - [x] Part 1, 2026-11-17: the graph's visible time window (timeframe, pinch zoom,
    axis ranges) moved to `BACGraphWindow`, with unit tests.
- [x] **Q3: fetch member avatars in one query.** `fetchLobbyAnalytics` and
  `fetchMemberLocations` run one `profiles` request per member, the second one every
  20 seconds. Done 2026-11-16.
- [x] **Q4: stop re-simulating every member's BAC on each render.** `body` calls
  `buildBacSnapshot`, so it reruns on every keystroke in the drink form. Done
  2026-11-17: `BACSnapshotCache`.
- [x] **Q5: share the quick-add types between app and widget.** `AppIntent.swift`
  redeclares `QuickAddDrinkPreset`, `LobbyQuickAddContext` and the presets.
  Done 2026-11-14.
- [x] **Q6: remove dead code**: `AuthOTP.swift` (magic link, unused), the
  `SwiftData` import, the unused `mapRegion` San Francisco default. Done
  2026-11-15.
- [ ] **Q6b (after S1): remove the `bac_etimate` legacy fallback** once S1 confirms
  the column name. Split out of Q6.
- [x] **Q7: repo hygiene**: untrack `xcuserdata`, fuller `.gitignore`, a README
  with setup steps (`Secrets.xcconfig`, Supabase). Done 2026-11-15.
- [ ] **Q8: replace polling with Supabase Realtime** for drinks, motions and
  locations (after S1).

## 4. UX

- [x] **U1: lobby header**: drop the raw lobby UUID, add a share button for the
  invite code.
- [x] **U2: friendlier errors.** Status lines show raw `localizedDescription` from
  the network layer.
- [x] **U3: map**: frame all visible members, add a re-centre button; today it
  centres once on the first row returned.
- [x] **U4: fix login copy** ("individuals inebreation"). Done 2026-11-16.
- [ ] **U5 `needs-owner`: Sign in with Apple.** Google is the only sign-in; App
  Store review generally expects an equivalent option alongside third-party login.
- [ ] **U6 `needs-owner`: deployment target is iOS 26.2**, so only phones on the
  newest iOS can install. Lower it?
- [ ] **U7: "Leave Lobby" deletes your drinks on a single tap.** "Closing Time"
  and "Delete Lobby" both need a second confirming tap; "Leave Lobby" calls
  `leaveLobby` at once, which deletes the user's drinks, BAC parameters and
  membership for that lobby with no way back. Ask for confirmation in the same
  two-tap style, with a line saying that the drinks logged in this lobby are
  removed. Found 2026-11-18.
- [ ] **U8: Lock Screen quick-add shows developer and raw server text.** The
  dialogs in `BeerPartyWidget/AppIntent.swift` read "No active lobby found. Verify
  App Group is enabled on app and widget." and "Could not add drink. Supabase 401:
  {...}" (the raw response body). After the token expires on a locked phone (B4)
  that 401 text is what the user sees. Map the cases to short sentences: no lobby
  context, expired sign-in ("Open BeerParty to keep adding drinks."), offline,
  anything else. The mapping should be a small function shared with the tests
  (the widget cannot see `UserFacingError` today; U2 left this open). Found
  2026-11-18.
