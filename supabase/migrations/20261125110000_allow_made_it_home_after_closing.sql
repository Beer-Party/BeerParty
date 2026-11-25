-- Allow "made it home" for 5 hours after closing time (backlog U12).
--
-- 20261115110000_create_lobby_events.sql lets a member add a made_it_home event
-- only while the lobby is open. But the host usually taps "Closing Time" when
-- the group leaves the bar, which is just before people walk home and want to
-- say they arrived. The lobby screens keep reading new events for 5 hours after
-- closing, and the app (from the pull request that adds this file) lets members
-- send "Made it home" during those 5 hours. This file gives lobby_events the
-- same rule:
--
--   made_it_home  any member, for themselves, while the lobby is open, or
--                 within 5 hours of the lobby's lobby_closed event
--
-- The other two kinds keep exactly the rules of the earlier file.
--
-- Run this AFTER 20261115110000_create_lobby_events.sql (it replaces that
-- file's insert policy). The app does not write lobby_events yet (B5 step 3),
-- so nothing changes for users until then.
--
-- Not applied automatically. An owner runs this in the Supabase SQL editor (or
-- `supabase db push`). Safe to run more than once.

drop policy if exists lobby_events_insert_member on public.lobby_events;
create policy lobby_events_insert_member
on public.lobby_events
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.lobby_members lm
    where lm.lobby_id = lobby_events.lobby_id
      and lm.user_id = auth.uid()
  )
  and (
    (
      kind = 'made_it_home'
      and (
        exists (
          select 1
          from public.lobbies l
          where l.id = lobby_events.lobby_id
            and l.is_active = true
        )
        or exists (
          select 1
          from public.lobby_events closed
          where closed.lobby_id = lobby_events.lobby_id
            and closed.kind = 'lobby_closed'
            and closed.created_at > now() - interval '5 hours'
        )
      )
    )
    or (
      kind = 'lobby_closed'
      and exists (
        select 1
        from public.lobbies l
        where l.id = lobby_events.lobby_id
          and l.created_by = auth.uid()
          and l.is_active = false
      )
    )
    or (
      kind = 'motion_due'
      and exists (
        select 1
        from public.motions m
        where m.id = lobby_events.motion_id
          and m.lobby_id = lobby_events.lobby_id
          and m.passed = true
      )
    )
  )
);
