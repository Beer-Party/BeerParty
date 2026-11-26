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
- [x] **S8: signing out leaves the Lock Screen quick-add signed in.**
  `PreLobbyView.signOut` only calls `supabase.auth.signOut()`. The quick-add
  context in the shared app group (`lobby.quickadd.context`, which holds the
  access token) and the Live Activity are removed only by lobby-screen actions
  (leave, close, delete, switching the toggle off). After sign-out the Lock Screen
  buttons therefore keep adding drinks and votes as the previous user until the
  token expires (up to an hour), and the token stays on disk. Call
  `LobbyLiveActivityService.endContext()` on sign-out and on the signed-out auth
  event. Found 2026-11-18. Done 2026-11-19.
- [ ] **S9 `needs-owner`: profile photos can be fetched by anyone who has the
  link.** `ProfileImageService.publicImageURL` uses `getPublicURL` on the
  `profile_pics` bucket, so the bucket is public: a photo at
  `<user id>/avatar.jpg` loads without signing in, for ever, and also after the
  user has left every lobby. Owner decides: keep it public (simple, and user ids
  are hard to guess), or make the bucket private and have the app ask for
  short-lived signed links, readable only by people who share a lobby with the
  user. The second needs a storage policy change in Supabase, which only an owner
  can make. Found 2026-11-20.

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
  - [ ] Step 2 `needs-owner`: apply that file in the Supabase SQL editor, then
    `20261125110000_allow_made_it_home_after_closing.sql` (U12) once it is
    merged.
  - [ ] Step 3 (after step 2): the app writes and reads `lobby_events`, and still
    reads the old prefixed rows so phones on the old version keep working.
  - [ ] Step 4 (after step 3 has shipped): stop reading the prefixed rows and
    delete them (migration).
- [x] **B6: a decimal comma is rejected.** `LobbyView` parses volume and ABV with
  `Double(text)` (add form and edit sheet), and `ProfileSetupView` does the same
  for weight. The decimal keypad shows a comma in most European regions, and
  `Double("4,7")` is nil, so "Add Drink" and "Save" stay disabled with no
  explanation. Parse both separators in one shared helper, with unit tests. Found
  2026-11-17.
- [x] **B7: other members' edited and deleted drinks never arrive, and some new
  ones are missed.** The 30-second refresh asks only for drinks with `consumed_at`
  later than the newest one already shown (`fetchNewDrinks`). An edit or a delete
  changes no such row, so every other phone keeps the old drink in its BAC and
  graph until pull-to-refresh. `consumed_at` is also the adding phone's own clock,
  so a drink from a phone whose clock is behind falls before the cursor and is
  skipped. Reload the full drink list on a slower cycle (or compare ids), with the
  merge as a tested pure function. Found 2026-11-17.
- [x] **B8: two members with the same nickname share one line on the graph.** The
  chart groups and colours by `point.nickname`, and `latestPointByMember` is keyed
  by nickname; nothing stops two members from choosing the same one. Their points
  are drawn as a single zig-zag line with one label. Key the series by user id and
  keep the nickname for the label only. Found 2026-11-17.
- [x] **B9: drink input has no upper limits.** Volume only has to be above 0 and
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
- [x] **B10: a failed "Make Lobby" leaves a half-made lobby behind.**
  `MakeLobbyView.createLobby` sends four separate requests: insert into `lobbies`,
  then `lobby_members`, `member_state` and the BAC parameters. If the second one
  fails (connection drops), the lobby row exists with no members: it appears in
  nobody's list, and trying again says "That invite code is already in use". Move
  the steps into one function on `LobbyBackendService` that deletes the lobby row
  again when a later step fails, with the order of steps unit-tested; the proper
  fix is a single `create_lobby` database function after S1. Found 2026-11-18.
  Done 2026-11-19 in the app; the database function still waits for S1.
- [x] **B11: Lock Screen quick-add still adds drinks after the lobby is closed.**
  The app's `insertDrink` refuses when the lobby is closed, but the widget's
  `QuickAddDrinkIntent` posts straight to `drinks` with no such check. The Live
  Activity is ended only if this phone has the lobby screen open when the lobby
  closes (`refreshLobbyActivityStatus`), so a locked phone keeps its buttons and
  its drinks land in a closed lobby (also after the 24-hour auto-close). In the
  intent, read `lobbies.is_active` first; when closed, end the activity and say
  so. A database rule belongs with S1. Found 2026-11-18. Done 2026-11-19 in the
  widget; the database rule still waits for S1.
- [x] **B12: location sharing does not start the first time permission is
  given.** `LocationTrackingService.startTracking` only asks for permission when
  the status is "not determined" and returns without setting `isTracking`. When
  the user then taps "Allow", `locationManagerDidChangeAuthorization` starts
  updates only if `isTracking` is true, so nothing starts. The toggle is on but no
  pin appears until the user switches it off and on, or leaves the lobby and comes
  back. Remember that tracking was asked for and start it when permission arrives;
  put the decision ("ask", "start", "stop" for each permission status) in a small
  tested function. When permission is refused the toggle also stays on with no
  explanation: show one line pointing to Settings. Found 2026-11-20. Done
  2026-11-21; device check still open.
- [x] **B13: one failed refresh empties "Your Lobbies".**
  `PreLobbyView.loadMemberLobbies` sets `memberLobbies = []` in its `catch`, so a
  single failed request (no signal in a bar) replaces the list with only an error
  line and there is no way to get into a lobby until the screen appears again.
  Keep the list that is already shown when a reload fails, and add
  pull-to-refresh to the screen (the lobby screen has it, this one does not).
  The sort order (open lobbies first, then newest) can move into a small tested
  function at the same time. Found 2026-11-20. Done 2026-11-21.
- [x] **B14: a changed profile photo keeps showing the old one.** The photo is
  always uploaded to the same path, `<user id>/avatar.jpg`, with `upsert`, so its
  public link never changes. `AsyncImage` and the storage CDN cache by link, so
  the user and the other lobby members go on seeing the old photo, often for
  hours. Upload under a new name each time (for example
  `avatar-<timestamp>.jpg`), save that path in `profiles.profile_pic_path`, and
  remove the previous file afterwards (best effort). The path naming should be a
  small tested function. Whether the app is allowed to delete the old file
  depends on the bucket's rules, which are not in the repo (S1). Found
  2026-11-20. Done 2026-11-21; whether the old file is really removed needs a
  check in the Supabase storage browser.
- [x] **B15: everyone's BAC is worked out with the same body values, whatever
  their weight and gender.** `ensureCurrentUserBACParams` in
  `LobbyBackendService` asks for `id,weight,age,gender` and decodes the answer as
  `UserProfile`. That type also requires `share_location_foreground` and
  `share_location_background`, which are not in the answer, so decoding always
  fails and the `catch` saves the fallback (body water 40, elimination 0.14) for
  every member. A 60 kg woman and a 100 kg man get the same BAC from the same
  drinks. Decode into a small type with only the four fields, and move
  `deriveBACParametersFromProfile` into a plain tested function (with a test that
  decodes exactly the JSON the query returns). Rows already saved in
  `lobby_member_bac_params` keep the fallback because a row is only written when
  none exists: also rewrite the user's own row when it differs from the derived
  values, which makes a changed weight count in lobbies joined earlier too. Found
  2026-11-22.
- [x] **B16: a member who stays in one place disappears from the map after five
  minutes.** `LocationTrackingService` reports a position only after 25 metres of
  movement (`distanceFilter = 25`), and the position is uploaded only then.
  `LobbyView.visibleLocationRows` hides every pin older than five minutes. A
  friend sitting in the bar, the usual case, is therefore gone from the map
  until they walk. While sharing is on, upload the last known position again
  when the last upload is more than about two minutes old (the 20-second
  location timer can do it); put the "is it time to send again" decision in a
  small tested function. Found 2026-11-22.
- [x] **B17: a motion "in 5 min" is announced up to five minutes late.** Voting
  always stays open for 10 minutes (`votingClosesAt: now + 10 min` in
  `createMotion`), but the delay picker starts at 5 minutes. If one member does
  not vote, the motion is decided only after 10 minutes, and "Motion time: Head
  towards ..." is shown then, five minutes after the time everyone agreed on.
  Close voting at the motion's own time when that is earlier than 10 minutes, as
  a small tested function, and say the same in the "Voting closes ..." line. The
  database function `close_expired_motions` only reads `voting_closes_at`, so it
  needs no change. Found 2026-11-22.
- [x] **B18: the widget's custom button probably gets an empty name.**
  `LobbyView.addManualDrink` adds the drink first and builds the custom button
  afterwards from the form's name, but `addDrink` has already emptied the form by
  then. The button is saved with the right volume and ABV and the name "", so
  the "Custom button:" line shows no name and a drink added with it from the
  Lock Screen has an empty name in the drink history. Read the name once before
  adding the drink; build the preset in a small tested function that refuses an
  empty name. Check on a device first (add a manual drink with "Use as widget
  custom button" on, then look at the "Custom button:" line). Found 2026-11-22.
- [x] **B19: the graph of a past lobby runs all the way to today.**
  `BACCalculator.snapshot` simulates every member from the lobby's first drink
  up to the current time, also when the lobby closed days ago
  (`loadLobbyAnalytics` sets `now = Date()` for a closed lobby too). Opening
  last week's lobby from "Your Lobbies" shows a graph one week wide with the
  whole evening squeezed into its left edge, and "2h" and "5h" show only flat
  lines at zero. The work also grows with the lobby's age (one step per ten
  minutes, per member, per drink) and is redone on the main thread every 30
  seconds. End the graph where it stops changing: the time of the last drink
  plus the time until everyone is back at zero, never later than now. Put that
  end time in a small tested function. Found 2026-11-24.
- [x] **B20: a lobby the host deleted stays open on everyone else's phone.**
  When the creator taps "Delete Lobby", the other members' lobby screens are not
  told. `refreshLobbyActivityStatus` gets `lobbyNotFound` and ignores it as a
  passing failure, so the screen keeps saying "Status: Active"; the member list
  can then empty ("No members found in this lobby.") and every "Add Drink"
  fails with "Lobby not found." The Lock Screen buttons are worse off: the widget's
  check reads an empty answer as "unknown" (`LobbyOpenState.from`), tries the
  drink anyway and says "Please try again." every time. Treat "the lobby row is
  gone" as its own case: in the app, end quick add and location sharing, say
  "This lobby was deleted by its host." and go back to the hub; in the widget,
  end the Live Activity as for a closed lobby. The decision ("open", "closed",
  "gone", "unknown") extends the tested `LobbyOpenState`. Found 2026-11-24.
- [x] **B21: a member's changed body values or nickname never reach the other
  phones.** `refreshMembersIfNeeded` reloads the member list and the BAC values
  only when the set of member ids changes (`LobbyRoster.needsReload`). Since B15
  a member's values in `lobby_member_bac_params` are rewritten when their
  profile weight changes, and a member who joins again with the invite code
  gets a new nickname, but the set of ids stays the same, so everybody else
  keeps calculating that member's BAC with the old values (and shows the old
  name) until they pull to refresh. The same happens when a phone polls in the
  moment between a new member's `lobby_members` row and their BAC row: it then
  uses the fallback values for that member for the rest of the night. Reload
  the roster on a slow cycle as well (the two-minute drink reload can do it),
  and at once when a shown member has no BAC values; keep "does the roster
  differ" as a tested function that also compares nicknames and values. Found
  2026-11-24.
- [ ] **B22: the Lock Screen vote buttons stay after voting, and still vote
  when the motion is over.** `CastMotionVoteIntent` sends the vote and says
  "Aye vote submitted.", but changes neither the saved quick-add context nor
  the Live Activity, so "Aye" and "Neigh" stay on the Lock Screen. A second tap
  silently changes the vote (the vote is an upsert). On a locked phone the
  buttons also stay after the motion has been decided, because only an open
  lobby screen updates them (`syncLiveActivityContext`), and a tap then writes
  a vote for a closed motion and still says "submitted". After a successful
  vote, save `shouldShowMotionVote = false` in the context and update the
  activity's content state; before voting, read the motion's `status` (one
  request, as `lobbyOpenState` does for drinks) and say "Voting on this motion
  is over." when it is closed. The reading of that answer should be a small
  tested function next to `LobbyOpenState`. Found 2026-11-25.
- [x] **B23: the profile accepts any weight and age.** `ProfileSetupView`
  only checks weight > 0 and age > 0. A slip such as 750 instead of 75 kg is
  saved, and since B15 it is really used: that member's BAC comes out about
  ten times too low on every phone in the lobby (the maths has a floor of 40
  kg but no ceiling). Age 400 is accepted as well. Reject weights outside
  about 30 to 300 kg (in the unit shown) and ages above 120, with a short line
  under the field, as a small tested function like `DrinkInputLimits`.
  Whether there should be a minimum age (the legal drinking age differs by
  country) is an owner decision and not part of this item. Found 2026-11-25.
- [ ] **B24: background failures put an error on the screen every few
  minutes.** `syncCurrentUserBACIfNeeded` writes "Couldn't update your BAC for
  the lobby ..." into the status line when the five-minute background write
  fails, and tries again (and fails again) every five minutes while the phone
  has no signal. `handleOwnLocationUpdate` does the same with "Couldn't share
  your location" on every position update while walking without signal. Both
  overwrite whatever the user just did ("Added Beer.") with a message they
  cannot act on; with the status banner of #51 it pops up at the bottom of
  the screen again and again. Keep these messages for actions the user
  started (adding a drink, switching sharing on) and stay silent for the timed
  and automatic ones; the "report or stay silent" decision can be a small
  tested function. Found 2026-11-25.

## 3. Code health

- [x] **Q1: move the BAC maths out of `LobbyView` into a plain type with unit
  tests.** It is private view code today, and the test target has no real tests.
  Done 2026-11-14: `BACCalculator`.
- [ ] **Q2: split `LobbyView.swift` (1,915 lines, about 60 `@State` properties)**
  into a view model plus one view per section. Several PRs.
  - [x] Part 1, 2026-11-17: the graph's visible time window (timeframe, pinch zoom,
    axis ranges) moved to `BACGraphWindow`, with unit tests.
  - [x] Part 2, 2026-11-18: reading the system-event rows ("made it home", "lobby
    closed", "motion due") moved to `LobbySystemEvent`, with unit tests.
  - [x] Part 3, 2026-11-19: the buddy comparison moved to `BuddyComparison`, with
    unit tests.
  - [x] Part 4, 2026-11-20: choosing the graph point under a long press moved to
    `BACGraphInspection`, with unit tests.
  - [x] Part 5, 2026-11-21: deciding a motion (voting over, passed, time to
    announce it) moved to `MotionTally`, with unit tests.
  - [x] Part 6, 2026-11-22: the text typed into the "Add Drink" form and the
    "Edit Drink" sheet moved to `DrinkDraft`, with unit tests; the sheet is its
    own view, `DrinkEditSheet`.
  - [x] Part 7, 2026-11-23: the "Drink History" section is its own view,
    `DrinkHistorySection`; which drinks it lists and which can still be changed
    moved to `DrinkHistory`, with unit tests.
  - [x] Part 8, 2026-11-24: the "Add Drink" and "Widget" sections are their own
    views, `AddDrinkSection` and `QuickAddWidgetSection`. View code only, so no
    new unit tests.
  - [x] Part 9, 2026-11-25: the "Motions" section (new motion form and past
    motions) is its own view, `MotionsSection`. View code only, so no new unit
    tests.
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
- [ ] **Q9: the motions are fetched twice every 30 seconds.**
  `refreshMotionsIfNeeded` loads motions and votes (two requests), then
  `resolveAndNotifyMotionsIfNeeded` always loads both again, also when no
  motion was closed and nothing was announced, which is nearly always. That
  is four requests per phone every 30 seconds just for motions. Fetch again
  only when this phone closed a motion or wrote a "motion due" note; the
  "fetch again?" decision can be a small tested function. Found 2026-11-25.

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
- [x] **U7: "Leave Lobby" deletes your drinks on a single tap.** "Closing Time"
  and "Delete Lobby" both need a second confirming tap; "Leave Lobby" calls
  `leaveLobby` at once, which deletes the user's drinks, BAC parameters and
  membership for that lobby with no way back. Ask for confirmation in the same
  two-tap style, with a line saying that the drinks logged in this lobby are
  removed. Found 2026-11-18. Done 2026-11-19; device check still open.
- [x] **U8: Lock Screen quick-add shows developer and raw server text.** The
  dialogs in `BeerPartyWidget/AppIntent.swift` read "No active lobby found. Verify
  App Group is enabled on app and widget." and "Could not add drink. Supabase 401:
  {...}" (the raw response body). After the token expires on a locked phone (B4)
  that 401 text is what the user sees. Map the cases to short sentences: no lobby
  context, expired sign-in ("Open BeerParty to keep adding drinks."), offline,
  anything else. The mapping should be a small function shared with the tests
  (the widget cannot see `UserFacingError` today; U2 left this open). Found
  2026-11-18. Done 2026-11-19.
- [x] **U9: the invite code is hidden while typing and has two names.** "Join
  Lobby" asks for the "Invite code" in a `SecureField`, and "Make Lobby" calls
  the same thing "Lobby password", also hidden. The code is then shown in plain
  text in the lobby header and sent to friends with the share button (U1), so
  hiding it protects nothing, and a typo while joining only shows up as "no
  lobby found". Use a normal text field (no autocorrection, no capitalisation)
  on both screens and call it "Invite code" everywhere. Found 2026-11-20. Done
  2026-11-21.
- [x] **U10: invite codes only work in exactly the same capital and small
  letters.** `joinLobby` looks the code up with an exact match, so a friend who
  is told "beer" and types "Beer" (or the other way round) only sees "No active
  lobby found for that invite code". Compare without regard to case when
  joining and when "Make Lobby" checks that a code is free (`ilike`, with `%`,
  `_` and `\` in the typed code escaped; the escaping is a small tested
  function). Two existing lobbies whose codes differ only in case then both
  match: keep the present "multiple lobbies share that invite code" message for
  that. The lasting fix, generated codes, is part of S2. Found 2026-11-22.
- [x] **U11: the weight field always starts in pounds.** `ProfileSetupView`
  sets `selectedWeightUnit = .pounds` for everyone and shows "Weight (lbs)". A
  new user in Europe who types 75 without noticing the unit is saved as 75 lbs
  (34 kg). Since B15 the weight really is used, so that user's BAC comes out
  too high (the maths has a floor of 40 kg; for a 75 kg person that is about
  40 % above the right value).
  "Edit Profile" also shows a weight entered in kilograms converted to pounds
  each time. Start with the unit of the phone's region (`Locale.current
  .measurementSystem`: kilograms unless it is US or UK), as a small tested
  function, and show the saved weight in that unit. Nothing changes in the
  database: the weight is still stored in pounds. Found 2026-11-24. Done
  2026-11-25; device check still open.
- [ ] **U12: "Made it home" stops working at closing time.** The button is
  disabled when the lobby is closed, and `sendMadeItHome` refuses as well. But
  the host normally taps "Closing Time" when the group leaves the bar, which is
  just before people walk home and want to say they arrived. The other phones
  would still show the message: they keep reading new rows for five hours
  after closing (`shouldContinueLiveUpdates`). Allow "Made it home" during
  those five hours (the rule for "can still be sent" as a small tested
  function, shared by the button and the service). The `lobby_events`
  migration (B5 step 1, not applied yet) only allows `made_it_home` rows in an
  open lobby; ship a new migration file that relaxes that rule to the same
  five hours, for an owner to apply together with step 2. Found 2026-11-24.
  Done 2026-11-25 in the pull request that adds
  `20261125110000_allow_made_it_home_after_closing.sql`; the box is left
  unticked there only because #53 changes the line right above it. Tick it
  when merging.
