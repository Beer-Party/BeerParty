# 2026-11-26: S1, the database schema is in the repo

- Asked for by an owner in the session of the daily run, after the four
  waiting migration files had been applied (also today, by the owner; checked
  afterwards against the database).
- New file `supabase/schema.sql`: tables with their constraints, indexes,
  functions, triggers, row level security policies, grants, the storage
  bucket settings and policies, and the one scheduled job. Taken by reading
  the Postgres catalogs through read-only queries. No rows were read and
  nothing in the project was changed.
- It is a snapshot for reading, not a migration: it sits outside
  `supabase/migrations/` so `supabase db push` never runs it, and its header
  says so. The backlog item said "into `supabase/migrations/`"; a file there
  that must never be run seemed the worse choice. It goes out of date when a
  migration is applied; take it again then.
- `README.md` and `BACKLOG.md` updated: S1 ticked, the four applied
  migrations ticked (section 0 and B5 step 2), and what the schema showed
  added to the items it belongs to.

## What the schema showed

Worst first. All of this is from reading the rules, not from trying it.

1. **Anyone with an account can join any open lobby without the code**
   (new item S11). `lm_insert_self` lets a user insert a `lobby_members` row
   for any lobby, and `lobbies_select_active` lists every open lobby. A member
   can read live locations, drinks, and (next point) body data.
2. **Members can read each other's weight, age and gender** (S6, confirmed).
   `profiles_select_same_lobby` gives the whole row to anyone sharing a
   lobby. With point 1, that is anyone with an account.
3. **Leaving a lobby and editing or deleting a drink most likely do nothing**
   (new item B27): there is no DELETE rule on `drinks`, `lobby_members`,
   `member_state`, `lobby_member_bac_params`, and no UPDATE rule on `drinks`.
4. **Any member can rewrite any column of a motion** (S4, as assumed).
   `close_expired_motions` exists, now with the right tally, but nothing
   calls it: no scheduled job and no call from the app.
5. **Profile photos are public** (S9, confirmed): the bucket is public and
   has a read rule for everyone. Users can delete their own files, so the
   old-photo clean-up of B14 is allowed.
6. `drinks.volume_ml` is an integer and `abv` is `numeric(4,2)` (new item
   B28).
7. Smaller things, no item:
   - The database already closes a motion when every member has voted
     (trigger on `motion_votes`), recomputes a user's BAC values in all their
     lobbies when the profile changes (trigger on `profiles`), and refuses a
     vote on a motion that is closed or past its voting time
     (`motion_votes_insert_member`). The note in #62 that the database
     accepts such a vote was wrong; the app-side check there is still right,
     because it gives the user a clear sentence.
   - The column is `member_state.bac_estimate`, so Q6b (remove the
     `bac_etimate` fallback) can go ahead.
   - `create_lobby`, `join_lobby` and `generate_invite_code` exist and are
     unused; so are the table `posts` and the bucket `lobby-photos`
     (leftovers of a photo feature).
   - Several tables carry two or three policies that say the same thing
     (`lobbies` select, `member_state`, `lobby_member_bac_params`). Harmless,
     but it is how the loose one in point 1 hid next to a strict one. Worth a
     clean-up migration once S11 is done.
   - Only the creator can set `lobbies.is_active`, so the app's 24-hour
     auto-close does nothing when a guest's phone is the one that notices;
     the lobby is shown as closed on that phone only.
   - A lobby's invite code stays taken after the lobby is closed
     (`lobbies_invite_code_key` is unique over all lobbies).
   - No table is in the realtime publication (Q8 has to add them).

## Now free for the agent

S4, B9b, Q6b and Q8 were waiting for S1 and are no longer blocked; B5 step 3
is free now that the events table exists; S11 and B27 are new. S2, S6 and S7
still carry `needs-owner`. For S2 and S6 the open question was the schema,
which is answered; remove the tag if the agent should write those migrations.

- Verified: CI (the file is not built). The counts in the file were checked
  against the database: 10 tables, 11 indexes, 10 functions, 4 triggers, 44
  policies on `public` tables and 4 on `storage.objects`.
- Human check: nothing to run. Please read "What the schema showed", and try
  point 3 on a phone ("Leave Lobby" as a guest, then look at "Your Lobbies";
  edit a drink within 15 minutes).
