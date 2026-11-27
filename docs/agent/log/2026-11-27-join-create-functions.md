# 2026-11-27: S11 step 1a, database functions for joining and making a lobby

- Why: today any signed-in user can insert their own row into
  `lobby_members` for any lobby (`lm_insert_self`), and can list every open
  lobby (`lobbies_select_active`), because the app joins by reading
  `lobbies` and inserting the row itself. The loose rules can only go once
  the app no longer needs them.
- New file
  `supabase/migrations/20261127120000_join_and_create_lobby_functions.sql`.
  It only adds two functions; no table, policy or row changes, and the app
  does not call them yet, so applying it changes nothing for users.
  - `join_lobby(p_invite_code, p_nickname)`: finds the open lobby for the
    code (case does not matter; a code spelled exactly as typed wins, as
    `LobbyInvite.match` does), makes the caller a member, returns the lobby's
    id and name. Joining again changes the nickname and keeps the role (the
    app's upsert today turns a host who joins again into a guest).
  - `create_lobby(p_name, p_invite_code, p_nickname)`: lobby, member row
    (role `admin`) and `member_state` row in one step, so a failure cannot
    leave a lobby without members (the rest of B10). Refuses a code that is
    in use, also in another case; first removes the caller's own memberless
    lobby with that code, as the app does.
  - Both check `auth.uid()`, run as security definer with an empty search
    path, and can be called by signed-in users only. Errors carry codes the
    app can tell apart (listed in the file's header).
- Split: the backlog asked for "a migration that only adds the two
  functions, and the app calling them". The app part is left for the next
  step (1b), after an owner has applied the file: an app that calls a
  function the database does not have yet could not join or make lobbies.
  The backlog item now lists steps 1a, 1b and 2.
- Decisions made, say so if they should differ:
  - Invite codes stay chosen by the user, at least 4 characters. Generated
    codes are S2, which is tagged needs-owner. A short code can be guessed
    by trying, through the function as through the app today.
  - The older unused functions `join_lobby(text)` and `create_lobby(text)`
    are left in place; they can be dropped in step 2.
  - The functions do not write `lobby_member_bac_params`; the app goes on
    doing that after the call (members are allowed to).
- Verified: run against a local Postgres built from `supabase/schema.sql`
  (not the live project), 28 checks: applying twice, creating, joining with
  another case and with spaces, joining again, wrong, empty and
  pattern-character codes, two lobbies whose codes differ only in case,
  closed lobbies, a taken code, the memberless-lobby clean-up, calls without
  a user and as `anon`. CI does not run SQL.
- Human must do: after merging, run the file in the Supabase SQL editor and
  tick its line in section 0 of the backlog. The next run then switches the
  app over (step 1b).
- Backlog: S11 not ticked; step 1a ticked, the file listed in section 0.
