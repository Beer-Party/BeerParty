-- Fix close_expired_motions: count ayes and members separately.
--
-- The previous version joined motion_votes and lobby_members in one pass, so each
-- aye vote was repeated once per lobby member before being counted. One aye in a
-- five-person lobby was tallied as 5/5 and the motion passed. Any expired motion
-- with at least one aye passed, whatever the real share was.
--
-- This version counts each side in its own subquery. The pass rule itself is
-- unchanged: strictly more than two thirds of lobby members voted aye.
--
-- Not applied automatically. An owner runs this in the Supabase SQL editor (or
-- `supabase db push`). Safe to run more than once. It changes the function only;
-- motions that were already closed keep the result they have.

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
