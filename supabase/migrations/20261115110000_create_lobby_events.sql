-- Create lobby_events: a proper home for "made it home", "lobby closed" and
-- "motion due" (backlog B5, step 1 of several).
--
-- Today these three events are rows in public.drinks whose name starts with a
-- magic prefix (__home__:, __closed__:, __motion_due__:). Any member can insert
-- such a row, so any member can announce that the lobby closed or that a motion
-- is due, and a real drink whose name starts with one of the prefixes is hidden.
--
-- This file only adds the table and its rules. The app does not read or write it
-- yet; later pull requests switch the app over and then drop the prefixes.
--
-- An event row carries no free text. The app shows the member's nickname from
-- lobby_members, the motion's text from motions, and the time from created_at
-- (set by the server), so there is nothing in a row that a member can make up.
--
-- Who may add what (row level security):
--   made_it_home  any member, for themselves, while the lobby is open
--   lobby_closed  the lobby's creator, once the lobby is closed; once per lobby
--   motion_due    any member, for a motion of this lobby that passed; once per
--                 motion
-- Members of a lobby can read its events. Nobody can change or delete an event;
-- events go when the lobby is deleted.
--
-- Not applied automatically. An owner runs this in the Supabase SQL editor (or
-- `supabase db push`). Safe to run more than once.

create table if not exists public.lobby_events (
  id uuid primary key default gen_random_uuid(),
  lobby_id uuid not null references public.lobbies(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null,
  motion_id uuid references public.motions(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint lobby_events_kind_known
    check (kind in ('made_it_home', 'lobby_closed', 'motion_due')),
  constraint lobby_events_motion_only_for_motion_due
    check ((kind = 'motion_due') = (motion_id is not null))
);

create index if not exists idx_lobby_events_lobby_created_at
  on public.lobby_events(lobby_id, created_at);

-- Two phones can notice the same thing at the same moment; keep one row.
create unique index if not exists uq_lobby_events_one_due_per_motion
  on public.lobby_events(motion_id)
  where kind = 'motion_due';

create unique index if not exists uq_lobby_events_one_close_per_lobby
  on public.lobby_events(lobby_id)
  where kind = 'lobby_closed';

-- The time of an event is the server's, whatever the client sends.
create or replace function public.set_lobby_event_created_at()
returns trigger
language plpgsql
as $$
begin
  new.created_at := now();
  return new;
end;
$$;

drop trigger if exists trg_set_lobby_event_created_at on public.lobby_events;
create trigger trg_set_lobby_event_created_at
before insert on public.lobby_events
for each row execute function public.set_lobby_event_created_at();

alter table public.lobby_events enable row level security;

-- Signed-in users may read and add rows (subject to the policies below) and
-- nothing else. There is no update or delete policy, so both are refused.
revoke all on public.lobby_events from anon, authenticated;
grant select, insert on public.lobby_events to authenticated;

drop policy if exists lobby_events_select_member on public.lobby_events;
create policy lobby_events_select_member
on public.lobby_events
for select
to authenticated
using (
  exists (
    select 1
    from public.lobby_members lm
    where lm.lobby_id = lobby_events.lobby_id
      and lm.user_id = auth.uid()
  )
);

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
      and exists (
        select 1
        from public.lobbies l
        where l.id = lobby_events.lobby_id
          and l.is_active = true
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
