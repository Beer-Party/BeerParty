-- Server-side expiry for shared locations (S5).
--
-- member_state.lat/lng hold a member's last shared position. The app now clears
-- them when the user leaves the lobby view and when a closed lobby's 5-hour tail
-- ends, but a phone that is switched off, loses signal or has the app killed never
-- sends that clear, and its last coordinates would stay in the table for good.
--
-- clear_stale_member_locations() sets lat/lng to null on every row that has not
-- been written for longer than p_max_age (default one hour). The app already hides
-- positions older than five minutes, so nothing a user can see changes. Only the
-- coordinates are removed; the row, bac_estimate and updated_at are left alone.
--
-- The function is not callable from the app: execute is revoked from the client
-- roles, so it runs only from the SQL editor, the service role or a scheduled job.
--
-- Not applied automatically. An owner runs this in the Supabase SQL editor (or
-- `supabase db push`). Safe to run more than once.
--
-- On its own this file only creates the function. To have it run every 15 minutes,
-- also run the optional block at the bottom once (it enables the pg_cron extension,
-- which is not installed on the project today).

create or replace function public.clear_stale_member_locations(
  p_max_age interval default interval '1 hour'
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  cleared_count int;
begin
  update public.member_state
  set lat = null,
      lng = null
  where (lat is not null or lng is not null)
    and updated_at < now() - p_max_age;

  get diagnostics cleared_count = row_count;
  return cleared_count;
end;
$$;

revoke all on function public.clear_stale_member_locations(interval) from public;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on function public.clear_stale_member_locations(interval) from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    revoke all on function public.clear_stale_member_locations(interval) from authenticated;
  end if;
end;
$$;

-- Optional, run once by an owner: schedule the expiry every 15 minutes.
-- create extension if not exists pg_cron;
-- select cron.schedule(
--   'clear-stale-member-locations',
--   '*/15 * * * *',
--   $$select public.clear_stale_member_locations();$$
-- );
