-- Motions + votes schema for BeerParty
-- Run this in Supabase SQL editor.

create extension if not exists pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'motion_status') THEN
    CREATE TYPE public.motion_status AS ENUM ('active', 'closed');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'motion_vote_choice') THEN
    CREATE TYPE public.motion_vote_choice AS ENUM ('aye', 'neigh');
  END IF;
END
$$;

create table if not exists public.motions (
  id uuid primary key default gen_random_uuid(),
  lobby_id uuid not null references public.lobbies(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  proposer_nickname text not null,
  target_text text not null,
  delay_minutes int not null check (delay_minutes between 5 and 45 and delay_minutes % 5 = 0),
  created_at timestamptz not null default now(),
  target_at timestamptz not null,
  voting_closes_at timestamptz not null,
  status public.motion_status not null default 'active',
  passed boolean,
  resolved_at timestamptz,
  notified_at timestamptz,
  constraint motions_target_after_create check (target_at >= created_at),
  constraint motions_vote_close_after_create check (voting_closes_at >= created_at)
);

create table if not exists public.motion_votes (
  motion_id uuid not null references public.motions(id) on delete cascade,
  lobby_id uuid not null references public.lobbies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  vote public.motion_vote_choice not null,
  voted_at timestamptz not null default now(),
  primary key (motion_id, user_id)
);

create index if not exists idx_motions_lobby_created_at on public.motions(lobby_id, created_at desc);
create index if not exists idx_motions_lobby_status on public.motions(lobby_id, status);
create index if not exists idx_motions_target_at on public.motions(target_at);
create index if not exists idx_motion_votes_lobby_motion on public.motion_votes(lobby_id, motion_id);

-- Keep computed timestamps correct if client omits them.
create or replace function public.set_motion_timestamps()
returns trigger
language plpgsql
as $$
begin
  if new.created_at is null then
    new.created_at := now();
  end if;

  if new.target_at is null then
    new.target_at := new.created_at + make_interval(mins => new.delay_minutes);
  end if;

  if new.voting_closes_at is null then
    new.voting_closes_at := new.created_at + interval '10 minutes';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_set_motion_timestamps on public.motions;
create trigger trg_set_motion_timestamps
before insert on public.motions
for each row execute function public.set_motion_timestamps();

-- Close an active motion once all lobby members have voted.
create or replace function public.close_motion_when_all_members_voted()
returns trigger
language plpgsql
as $$
declare
  member_count int;
  vote_count int;
  aye_count int;
  passed_result boolean;
begin
  select count(*) into member_count
  from public.lobby_members lm
  where lm.lobby_id = new.lobby_id;

  select count(*) into vote_count
  from public.motion_votes mv
  where mv.motion_id = new.motion_id;

  if member_count <= 0 or vote_count < member_count then
    return new;
  end if;

  select count(*) into aye_count
  from public.motion_votes mv
  where mv.motion_id = new.motion_id
    and mv.vote = 'aye';

  passed_result := (aye_count::numeric / member_count::numeric) > (2.0 / 3.0);

  update public.motions m
  set status = 'closed',
      passed = passed_result,
      resolved_at = coalesce(m.resolved_at, now())
  where m.id = new.motion_id
    and m.status = 'active';

  return new;
end;
$$;

drop trigger if exists trg_close_motion_when_all_members_voted on public.motion_votes;
create trigger trg_close_motion_when_all_members_voted
after insert or update on public.motion_votes
for each row execute function public.close_motion_when_all_members_voted();

-- Helper to close motions whose 10-minute vote window has elapsed.
create or replace function public.close_expired_motions(p_lobby_id uuid default null)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count int;
begin
  with candidates as (
    -- Ayes and members are counted separately: joining both in one pass
    -- multiplies the aye count by the member count.
    select m.id,
           (select count(*)
              from public.motion_votes mv
             where mv.motion_id = m.id
               and mv.vote = 'aye') as aye_count,
           greatest((select count(*)
                       from public.lobby_members lm
                      where lm.lobby_id = m.lobby_id), 1) as member_count
    from public.motions m
    where m.status = 'active'
      and m.voting_closes_at <= now()
      and (p_lobby_id is null or m.lobby_id = p_lobby_id)
  )
  update public.motions m
  set status = 'closed',
      passed = ((c.aye_count::numeric / c.member_count::numeric) > (2.0 / 3.0)),
      resolved_at = coalesce(m.resolved_at, now())
  from candidates c
  where m.id = c.id;

  get diagnostics updated_count = row_count;
  return updated_count;
end;
$$;

alter table public.motions enable row level security;
alter table public.motion_votes enable row level security;

-- Read motions/votes if user is in the lobby.
drop policy if exists motions_select_member on public.motions;
create policy motions_select_member
on public.motions
for select
using (
  exists (
    select 1
    from public.lobby_members lm
    where lm.lobby_id = motions.lobby_id
      and lm.user_id = auth.uid()
  )
);

drop policy if exists motion_votes_select_member on public.motion_votes;
create policy motion_votes_select_member
on public.motion_votes
for select
using (
  exists (
    select 1
    from public.lobby_members lm
    where lm.lobby_id = motion_votes.lobby_id
      and lm.user_id = auth.uid()
  )
);

-- Any lobby member can create a motion in an active lobby.
drop policy if exists motions_insert_member on public.motions;
create policy motions_insert_member
on public.motions
for insert
with check (
  created_by = auth.uid()
  and exists (
    select 1
    from public.lobby_members lm
    join public.lobbies l on l.id = lm.lobby_id
    where lm.lobby_id = motions.lobby_id
      and lm.user_id = auth.uid()
      and l.is_active = true
  )
);

-- Members can update motion state for closing/notifying while lobby is active.
drop policy if exists motions_update_member on public.motions;
create policy motions_update_member
on public.motions
for update
using (
  exists (
    select 1
    from public.lobby_members lm
    where lm.lobby_id = motions.lobby_id
      and lm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.lobby_members lm
    where lm.lobby_id = motions.lobby_id
      and lm.user_id = auth.uid()
  )
);

-- One vote per user per motion (upsert via PK).
drop policy if exists motion_votes_insert_member on public.motion_votes;
create policy motion_votes_insert_member
on public.motion_votes
for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.lobby_members lm
    where lm.lobby_id = motion_votes.lobby_id
      and lm.user_id = auth.uid()
  )
  and exists (
    select 1
    from public.motions m
    where m.id = motion_votes.motion_id
      and m.lobby_id = motion_votes.lobby_id
      and m.status = 'active'
      and m.voting_closes_at > now()
  )
);

drop policy if exists motion_votes_update_own on public.motion_votes;
create policy motion_votes_update_own
on public.motion_votes
for update
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.motions m
    where m.id = motion_votes.motion_id
      and m.status = 'active'
      and m.voting_closes_at > now()
  )
);

-- Optional: automatically close expired motions every minute if pg_cron is enabled.
-- select cron.schedule(
--   'close-expired-motions',
--   '* * * * *',
--   $$select public.close_expired_motions();$$
-- );
