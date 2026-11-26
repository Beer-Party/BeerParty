-- BeerParty: snapshot of the live database structure.
--
-- Taken on 2026-11-26 from the Supabase project "Beer Party" by reading the
-- Postgres catalogs (pg_get_functiondef, pg_policies, pg_constraint, ...).
-- It holds structure only: no rows, no user data, no keys.
--
-- THIS FILE IS A REFERENCE. DO NOT RUN IT against the project: everything in
-- it already exists there, and it is not written to be run twice. It is here
-- so that the tables and the access rules can be read and reviewed, and so
-- that new files in supabase/migrations/ can be written against what is
-- really there. It lives outside supabase/migrations/ on purpose, so that
-- `supabase db push` never picks it up.
--
-- It includes the four files in supabase/migrations/, which were applied on
-- 2026-11-26. When a later migration is applied, this snapshot is out of date
-- until someone takes it again.
--
-- Expressions (checks, policies, defaults) are printed the way Postgres
-- stores them, which is why they carry extra brackets and casts.
--
-- Contents: 1 types, 2 tables, 3 indexes, 4 functions, 5 triggers,
-- 6 row level security and policies, 7 grants, 8 storage, 9 scheduled jobs,
-- 10 realtime.

-- ---------------------------------------------------------------------------
-- 1. Types
-- ---------------------------------------------------------------------------

create type public.motion_status as enum ('active', 'closed');
create type public.motion_vote_choice as enum ('aye', 'neigh');

-- ---------------------------------------------------------------------------
-- 2. Tables (alphabetical; lobbies and motions are referenced by the others)
-- ---------------------------------------------------------------------------

create table public.drinks (
  id uuid not null default gen_random_uuid(),
  lobby_id uuid not null,
  user_id uuid not null,
  name text,
  volume_ml integer,
  abv numeric(4,2),
  consumed_at timestamp with time zone not null default now(),
  constraint drinks_pkey PRIMARY KEY (id),
  constraint drinks_lobby_id_fkey FOREIGN KEY (lobby_id) REFERENCES lobbies(id) ON DELETE CASCADE,
  constraint drinks_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

create table public.lobbies (
  id uuid not null default gen_random_uuid(),
  created_by uuid not null default auth.uid(),
  name text,
  invite_code text not null,
  created_at timestamp with time zone not null default now(),
  is_active boolean not null default true,
  constraint lobbies_invite_code_key UNIQUE (invite_code),
  constraint lobbies_pkey PRIMARY KEY (id),
  constraint lobbies_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id)
);

create table public.lobby_events (
  id uuid not null default gen_random_uuid(),
  lobby_id uuid not null,
  user_id uuid not null default auth.uid(),
  kind text not null,
  motion_id uuid,
  created_at timestamp with time zone not null default now(),
  constraint lobby_events_pkey PRIMARY KEY (id),
  constraint lobby_events_lobby_id_fkey FOREIGN KEY (lobby_id) REFERENCES lobbies(id) ON DELETE CASCADE,
  constraint lobby_events_motion_id_fkey FOREIGN KEY (motion_id) REFERENCES motions(id) ON DELETE CASCADE,
  constraint lobby_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint lobby_events_kind_known CHECK ((kind = ANY (ARRAY['made_it_home'::text, 'lobby_closed'::text, 'motion_due'::text]))),
  constraint lobby_events_motion_only_for_motion_due CHECK (((kind = 'motion_due'::text) = (motion_id IS NOT NULL)))
);

create table public.lobby_member_bac_params (
  lobby_id uuid not null,
  user_id uuid not null,
  tbw double precision not null,
  elim_rate double precision not null,
  updated_at timestamp with time zone not null default now(),
  constraint lobby_member_bac_params_pkey PRIMARY KEY (lobby_id, user_id),
  constraint lobby_member_bac_params_lobby_id_fkey FOREIGN KEY (lobby_id) REFERENCES lobbies(id) ON DELETE CASCADE,
  constraint lobby_member_bac_params_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint lobby_member_bac_params_elim_rate_check CHECK ((elim_rate > (0)::double precision)),
  constraint lobby_member_bac_params_tbw_check CHECK ((tbw > (0)::double precision))
);

create table public.lobby_members (
  lobby_id uuid not null,
  user_id uuid not null,
  role text not null default 'member'::text,
  joined_at timestamp with time zone not null default now(),
  nickname text,
  constraint lobby_members_lobby_user_unique UNIQUE (lobby_id, user_id),
  constraint lobby_members_pkey PRIMARY KEY (lobby_id, user_id),
  constraint lobby_members_lobby_id_fkey FOREIGN KEY (lobby_id) REFERENCES lobbies(id) ON DELETE CASCADE,
  constraint lobby_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint lobby_members_nickname_check CHECK ((length(nickname) < 30))
);

create table public.member_state (
  lobby_id uuid not null,
  user_id uuid not null,
  bac_estimate numeric(4,3),
  lat double precision,
  lng double precision,
  updated_at timestamp with time zone not null default now(),
  constraint member_state_lobby_user_unique UNIQUE (lobby_id, user_id),
  constraint member_state_pkey PRIMARY KEY (lobby_id, user_id),
  constraint member_state_lobby_id_fkey FOREIGN KEY (lobby_id) REFERENCES lobbies(id) ON DELETE CASCADE,
  constraint member_state_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint member_state_lat_range_check CHECK (((lat IS NULL) OR ((lat >= ('-90'::integer)::double precision) AND (lat <= (90)::double precision)))),
  constraint member_state_lng_range_check CHECK (((lng IS NULL) OR ((lng >= ('-180'::integer)::double precision) AND (lng <= (180)::double precision))))
);

create table public.motion_votes (
  motion_id uuid not null,
  lobby_id uuid not null,
  user_id uuid not null,
  vote motion_vote_choice not null,
  voted_at timestamp with time zone not null default now(),
  constraint motion_votes_pkey PRIMARY KEY (motion_id, user_id),
  constraint motion_votes_lobby_id_fkey FOREIGN KEY (lobby_id) REFERENCES lobbies(id) ON DELETE CASCADE,
  constraint motion_votes_motion_id_fkey FOREIGN KEY (motion_id) REFERENCES motions(id) ON DELETE CASCADE,
  constraint motion_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

create table public.motions (
  id uuid not null default gen_random_uuid(),
  lobby_id uuid not null,
  created_by uuid not null,
  proposer_nickname text not null,
  target_text text not null,
  delay_minutes integer not null,
  created_at timestamp with time zone not null default now(),
  target_at timestamp with time zone not null,
  voting_closes_at timestamp with time zone not null,
  status motion_status not null default 'active'::motion_status,
  passed boolean,
  resolved_at timestamp with time zone,
  notified_at timestamp with time zone,
  constraint motions_pkey PRIMARY KEY (id),
  constraint motions_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint motions_lobby_id_fkey FOREIGN KEY (lobby_id) REFERENCES lobbies(id) ON DELETE CASCADE,
  constraint motions_delay_minutes_check CHECK ((((delay_minutes >= 5) AND (delay_minutes <= 45)) AND ((delay_minutes % 5) = 0))),
  constraint motions_target_after_create CHECK ((target_at >= created_at)),
  constraint motions_vote_close_after_create CHECK ((voting_closes_at >= created_at))
);

-- Not used by the app.
create table public.posts (
  id uuid not null default gen_random_uuid(),
  lobby_id uuid not null,
  user_id uuid not null,
  image_path text not null,
  caption text,
  created_at timestamp with time zone not null default now(),
  constraint posts_pkey PRIMARY KEY (id),
  constraint posts_lobby_id_fkey FOREIGN KEY (lobby_id) REFERENCES lobbies(id) ON DELETE CASCADE,
  constraint posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

create table public.profiles (
  id uuid not null,
  weight numeric not null,
  age integer not null,
  gender text not null,
  created_at timestamp with time zone not null default now(),
  profile_pic_path text,
  share_location_foreground boolean not null default false,
  share_location_background boolean not null default false,
  constraint profiles_pkey PRIMARY KEY (id),
  constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- 3. Indexes (besides the ones behind the primary keys and unique constraints)
-- ---------------------------------------------------------------------------

CREATE INDEX idx_drinks_lobby_consumed_at ON public.drinks USING btree (lobby_id, consumed_at);
CREATE INDEX idx_drinks_lobby_user_consumed_at ON public.drinks USING btree (lobby_id, user_id, consumed_at);
CREATE UNIQUE INDEX ux_lobbies_invite_code_active ON public.lobbies USING btree (invite_code) WHERE (is_active = true);
CREATE INDEX idx_lobby_events_lobby_created_at ON public.lobby_events USING btree (lobby_id, created_at);
CREATE UNIQUE INDEX uq_lobby_events_one_close_per_lobby ON public.lobby_events USING btree (lobby_id) WHERE (kind = 'lobby_closed'::text);
CREATE UNIQUE INDEX uq_lobby_events_one_due_per_motion ON public.lobby_events USING btree (motion_id) WHERE (kind = 'motion_due'::text);
CREATE INDEX idx_lobby_member_bac_params_lobby ON public.lobby_member_bac_params USING btree (lobby_id);
CREATE INDEX idx_motion_votes_lobby_motion ON public.motion_votes USING btree (lobby_id, motion_id);
CREATE INDEX idx_motions_lobby_created_at ON public.motions USING btree (lobby_id, created_at DESC);
CREATE INDEX idx_motions_lobby_status ON public.motions USING btree (lobby_id, status);
CREATE INDEX idx_motions_target_at ON public.motions USING btree (target_at);

-- ---------------------------------------------------------------------------
-- 4. Functions
--
-- Who may call them (execute), as found:
--   clear_stale_member_locations  not anon, not authenticated (definer)
--   close_expired_motions         anon and authenticated      (definer)
--   create_lobby                  anon and authenticated      (definer)
--   is_lobby_member               anon and authenticated      (definer)
--   join_lobby                    anon and authenticated      (definer)
--   recompute_bac_params_from_profile  trigger function       (definer)
--   the other trigger functions and generate_invite_code run as the caller.
-- The app calls none of them directly today; create_lobby, join_lobby and
-- generate_invite_code are unused.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.clear_stale_member_locations(p_max_age interval DEFAULT '01:00:00'::interval)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.close_expired_motions(p_lobby_id uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.close_motion_when_all_members_voted()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.create_lobby(p_name text)
 RETURNS lobbies
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  new_lobby public.lobbies;
begin
  insert into public.lobbies (created_by, name, invite_code)
  values (auth.uid(), p_name, public.generate_invite_code())
  returning * into new_lobby;

  insert into public.lobby_members (lobby_id, user_id, role)
  values (new_lobby.id, auth.uid(), 'owner')
  on conflict do nothing;

  insert into public.member_state (lobby_id, user_id)
  values (new_lobby.id, auth.uid())
  on conflict do nothing;

  return new_lobby;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.generate_invite_code()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare
  code text;
begin
  loop
    code := upper(substring(replace(gen_random_uuid()::text, '-', '') from 1 for 6));
    exit when not exists (select 1 from public.lobbies where invite_code = code);
  end loop;
  return code;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.is_lobby_member(p_lobby_id uuid, p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1
    from public.lobby_members m
    where m.lobby_id = p_lobby_id
      and m.user_id = p_user_id
  );
$function$
;

CREATE OR REPLACE FUNCTION public.join_lobby(p_invite_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_lobby_id uuid;
begin
  select id into v_lobby_id
  from public.lobbies
  where invite_code = upper(p_invite_code)
    and is_active = true;

  if v_lobby_id is null then
    raise exception 'Invalid invite code';
  end if;

  insert into public.lobby_members (lobby_id, user_id, role)
  values (v_lobby_id, auth.uid(), 'member')
  on conflict do nothing;

  insert into public.member_state (lobby_id, user_id)
  values (v_lobby_id, auth.uid())
  on conflict do nothing;

  return v_lobby_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.recompute_bac_params_from_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  weight_kg double precision;
  derived_tbw double precision;
  derived_elim double precision;
begin
  weight_kg := greatest(40, new.weight / 2.20462);

  if lower(new.gender) like '%female%' then
    derived_tbw := greatest(20, 14.46 + 0.2549 * weight_kg);
    derived_elim := 0.15;
  elsif lower(new.gender) like '%male%' then
    derived_tbw := greatest(20, 20.03 - 0.1183 * new.age + 0.3626 * weight_kg);
    derived_elim := 0.13;
  else
    derived_tbw := greatest(20, 17.25 + 0.308 * weight_kg);
    derived_elim := 0.14;
  end if;

  update public.lobby_member_bac_params p
  set tbw = derived_tbw,
      elim_rate = derived_elim,
      updated_at = now()
  where p.user_id = new.id;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_lobby_event_created_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.created_at := now();
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_motion_timestamps()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$
;

-- ---------------------------------------------------------------------------
-- 5. Triggers
-- ---------------------------------------------------------------------------

CREATE TRIGGER trg_set_lobby_event_created_at BEFORE INSERT ON public.lobby_events FOR EACH ROW EXECUTE FUNCTION set_lobby_event_created_at();
CREATE TRIGGER trg_close_motion_when_all_members_voted AFTER INSERT OR UPDATE ON public.motion_votes FOR EACH ROW EXECUTE FUNCTION close_motion_when_all_members_voted();
CREATE TRIGGER trg_set_motion_timestamps BEFORE INSERT ON public.motions FOR EACH ROW EXECUTE FUNCTION set_motion_timestamps();
CREATE TRIGGER trg_profiles_recompute_bac_params AFTER INSERT OR UPDATE OF weight, age, gender ON public.profiles FOR EACH ROW EXECUTE FUNCTION recompute_bac_params_from_profile();

-- ---------------------------------------------------------------------------
-- 6. Row level security and policies
--
-- All policies are permissive: a row is allowed when ANY policy for that
-- command allows it. A command with no policy at all is refused for every
-- row, without an error: an UPDATE or DELETE simply changes nothing.
--
-- Commands with no policy on 2026-11-26:
--   drinks                    UPDATE, DELETE
--   lobby_members             DELETE
--   member_state              DELETE
--   lobby_member_bac_params   DELETE
--   motions                   DELETE
--   motion_votes              DELETE
--   lobby_events              UPDATE, DELETE (meant to be so)
--   posts                     UPDATE, DELETE
--   profiles                  DELETE
-- ---------------------------------------------------------------------------

alter table public.drinks enable row level security;
alter table public.lobbies enable row level security;
alter table public.lobby_events enable row level security;
alter table public.lobby_member_bac_params enable row level security;
alter table public.lobby_members enable row level security;
alter table public.member_state enable row level security;
alter table public.motion_votes enable row level security;
alter table public.motions enable row level security;
alter table public.posts enable row level security;
alter table public.profiles enable row level security;

-- drinks

create policy "user inserts own drinks"
on public.drinks
as permissive
for insert
to authenticated
with check ((is_lobby_member(lobby_id, auth.uid()) AND (user_id = auth.uid())));

create policy drinks_select_same_lobby
on public.drinks
as permissive
for select
to authenticated
using ((EXISTS ( SELECT 1
   FROM lobby_members me
  WHERE ((me.user_id = auth.uid()) AND (me.lobby_id = drinks.lobby_id)))));

create policy "members read drinks"
on public.drinks
as permissive
for select
to authenticated
using (is_lobby_member(lobby_id, auth.uid()));

-- lobbies

create policy lobbies_delete_creator
on public.lobbies
as permissive
for delete
to authenticated
using ((created_by = auth.uid()));

create policy lobbies_insert_creator
on public.lobbies
as permissive
for insert
to authenticated
with check ((created_by = auth.uid()));

create policy lobbies_select_active
on public.lobbies
as permissive
for select
to authenticated
using ((is_active = true));

create policy lobbies_select_creator_or_member
on public.lobbies
as permissive
for select
to authenticated
using (((created_by = auth.uid()) OR (EXISTS ( SELECT 1
   FROM lobby_members lm
  WHERE ((lm.lobby_id = lobbies.id) AND (lm.user_id = auth.uid()))))));

create policy lobbies_select_member_or_creator
on public.lobbies
as permissive
for select
to authenticated
using (((created_by = auth.uid()) OR (EXISTS ( SELECT 1
   FROM lobby_members lm
  WHERE ((lm.lobby_id = lobbies.id) AND (lm.user_id = auth.uid()))))));

create policy creator_can_update_own_lobby_is_active
on public.lobbies
as permissive
for update
to authenticated
using ((created_by = auth.uid()))
with check ((created_by = auth.uid()));

-- lobby_events

create policy lobby_events_insert_member
on public.lobby_events
as permissive
for insert
to authenticated
with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM lobby_members lm
  WHERE ((lm.lobby_id = lobby_events.lobby_id) AND (lm.user_id = auth.uid())))) AND (((kind = 'made_it_home'::text) AND ((EXISTS ( SELECT 1
   FROM lobbies l
  WHERE ((l.id = lobby_events.lobby_id) AND (l.is_active = true)))) OR (EXISTS ( SELECT 1
   FROM lobby_events closed
  WHERE ((closed.lobby_id = lobby_events.lobby_id) AND (closed.kind = 'lobby_closed'::text) AND (closed.created_at > (now() - '05:00:00'::interval))))))) OR ((kind = 'lobby_closed'::text) AND (EXISTS ( SELECT 1
   FROM lobbies l
  WHERE ((l.id = lobby_events.lobby_id) AND (l.created_by = auth.uid()) AND (l.is_active = false))))) OR ((kind = 'motion_due'::text) AND (EXISTS ( SELECT 1
   FROM motions m
  WHERE ((m.id = lobby_events.motion_id) AND (m.lobby_id = lobby_events.lobby_id) AND (m.passed = true))))))));

create policy lobby_events_select_member
on public.lobby_events
as permissive
for select
to authenticated
using ((EXISTS ( SELECT 1
   FROM lobby_members lm
  WHERE ((lm.lobby_id = lobby_events.lobby_id) AND (lm.user_id = auth.uid())))));

-- lobby_member_bac_params

create policy bac_params_insert_self
on public.lobby_member_bac_params
as permissive
for insert
to authenticated
with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM lobby_members lm
  WHERE ((lm.lobby_id = lobby_member_bac_params.lobby_id) AND (lm.user_id = auth.uid()))))));

create policy lobby_bac_params_insert_own
on public.lobby_member_bac_params
as permissive
for insert
to authenticated
with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM lobby_members me
  WHERE ((me.user_id = auth.uid()) AND (me.lobby_id = lobby_member_bac_params.lobby_id))))));

create policy bac_params_select_same_lobby
on public.lobby_member_bac_params
as permissive
for select
to authenticated
using ((EXISTS ( SELECT 1
   FROM lobby_members me
  WHERE ((me.user_id = auth.uid()) AND (me.lobby_id = lobby_member_bac_params.lobby_id)))));

create policy lobby_bac_params_select_same_lobby
on public.lobby_member_bac_params
as permissive
for select
to authenticated
using ((EXISTS ( SELECT 1
   FROM lobby_members me
  WHERE ((me.user_id = auth.uid()) AND (me.lobby_id = lobby_member_bac_params.lobby_id)))));

create policy bac_params_update_self
on public.lobby_member_bac_params
as permissive
for update
to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));

create policy lobby_bac_params_update_own
on public.lobby_member_bac_params
as permissive
for update
to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));

-- lobby_members

create policy lm_insert_self
on public.lobby_members
as permissive
for insert
to authenticated
with check ((user_id = auth.uid()));

create policy lobby_members_insert_self
on public.lobby_members
as permissive
for insert
to authenticated
with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM lobbies l
  WHERE ((l.id = lobby_members.lobby_id) AND (l.is_active = true))))));

create policy lm_select_self
on public.lobby_members
as permissive
for select
to authenticated
using ((user_id = auth.uid()));

create policy lobby_members_select_own
on public.lobby_members
as permissive
for select
to authenticated
using ((user_id = auth.uid()));

create policy lobby_members_select_same_lobby
on public.lobby_members
as permissive
for select
to authenticated
using (is_lobby_member(lobby_id, auth.uid()));

create policy lobby_members_update_self
on public.lobby_members
as permissive
for update
to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));

-- member_state

create policy member_state_insert_self
on public.member_state
as permissive
for insert
to authenticated
with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM lobby_members lm
  WHERE ((lm.lobby_id = member_state.lobby_id) AND (lm.user_id = auth.uid()))))));

create policy ms_insert_self
on public.member_state
as permissive
for insert
to authenticated
with check ((user_id = auth.uid()));

create policy "user updates own member_state"
on public.member_state
as permissive
for insert
to authenticated
with check ((is_lobby_member(lobby_id, auth.uid()) AND (user_id = auth.uid())));

create policy "members read member_state"
on public.member_state
as permissive
for select
to authenticated
using (is_lobby_member(lobby_id, auth.uid()));

create policy ms_select_self
on public.member_state
as permissive
for select
to authenticated
using ((user_id = auth.uid()));

create policy member_state_update_self
on public.member_state
as permissive
for update
to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));

create policy ms_update_self
on public.member_state
as permissive
for update
to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));

create policy "user updates own member_state rows"
on public.member_state
as permissive
for update
to authenticated
using ((is_lobby_member(lobby_id, auth.uid()) AND (user_id = auth.uid())));

-- motion_votes

create policy motion_votes_insert_member
on public.motion_votes
as permissive
for insert
to public
with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM lobby_members lm
  WHERE ((lm.lobby_id = motion_votes.lobby_id) AND (lm.user_id = auth.uid())))) AND (EXISTS ( SELECT 1
   FROM motions m
  WHERE ((m.id = motion_votes.motion_id) AND (m.lobby_id = motion_votes.lobby_id) AND (m.status = 'active'::motion_status) AND (m.voting_closes_at > now()))))));

create policy motion_votes_select_member
on public.motion_votes
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM lobby_members lm
  WHERE ((lm.lobby_id = motion_votes.lobby_id) AND (lm.user_id = auth.uid())))));

create policy motion_votes_update_own
on public.motion_votes
as permissive
for update
to public
using ((user_id = auth.uid()))
with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM motions m
  WHERE ((m.id = motion_votes.motion_id) AND (m.status = 'active'::motion_status) AND (m.voting_closes_at > now()))))));

-- motions

create policy motions_insert_member
on public.motions
as permissive
for insert
to public
with check (((created_by = auth.uid()) AND (EXISTS ( SELECT 1
   FROM (lobby_members lm
     JOIN lobbies l ON ((l.id = lm.lobby_id)))
  WHERE ((lm.lobby_id = motions.lobby_id) AND (lm.user_id = auth.uid()) AND (l.is_active = true))))));

create policy motions_select_member
on public.motions
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM lobby_members lm
  WHERE ((lm.lobby_id = motions.lobby_id) AND (lm.user_id = auth.uid())))));

create policy motions_update_member
on public.motions
as permissive
for update
to public
using ((EXISTS ( SELECT 1
   FROM lobby_members lm
  WHERE ((lm.lobby_id = motions.lobby_id) AND (lm.user_id = auth.uid())))))
with check ((EXISTS ( SELECT 1
   FROM lobby_members lm
  WHERE ((lm.lobby_id = motions.lobby_id) AND (lm.user_id = auth.uid())))));

-- posts

create policy "user inserts own posts"
on public.posts
as permissive
for insert
to authenticated
with check ((is_lobby_member(lobby_id, auth.uid()) AND (user_id = auth.uid())));

create policy "members read posts"
on public.posts
as permissive
for select
to authenticated
using (is_lobby_member(lobby_id, auth.uid()));

-- profiles

create policy "Profiles are insertable by owner"
on public.profiles
as permissive
for insert
to public
with check ((auth.uid() = id));

create policy "Profiles are viewable by owner"
on public.profiles
as permissive
for select
to public
using ((auth.uid() = id));

create policy profiles_select_own
on public.profiles
as permissive
for select
to authenticated
using ((id = auth.uid()));

create policy profiles_select_same_lobby
on public.profiles
as permissive
for select
to authenticated
using ((EXISTS ( SELECT 1
   FROM (lobby_members me
     JOIN lobby_members them ON ((me.lobby_id = them.lobby_id)))
  WHERE ((me.user_id = auth.uid()) AND (them.user_id = profiles.id)))));

create policy "Profiles are updatable by owner"
on public.profiles
as permissive
for update
to public
using ((auth.uid() = id));

-- ---------------------------------------------------------------------------
-- 7. Grants to the client roles
--
-- Row level security above decides which rows; these decide which commands
-- reach it at all. As found (the Supabase defaults, with two exceptions):
--   lobbies       no table-wide UPDATE; UPDATE only on the column is_active,
--                 for authenticated
--   lobby_events  only SELECT and INSERT, only for authenticated
-- ---------------------------------------------------------------------------

grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE on public.lobbies to anon;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE on public.lobbies to authenticated;
grant UPDATE (is_active) on public.lobbies to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.drinks to anon;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.drinks to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.lobby_member_bac_params to anon;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.lobby_member_bac_params to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.lobby_members to anon;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.lobby_members to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.member_state to anon;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.member_state to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.motion_votes to anon;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.motion_votes to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.motions to anon;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.motions to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.posts to anon;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.posts to authenticated;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.profiles to anon;
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.profiles to authenticated;
grant INSERT, SELECT on public.lobby_events to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Storage
--
-- Buckets (settings, as found):
--   profile_pics   public, at most 307200 bytes, image/jpeg, image/png,
--                  image/heic
--   lobby-photos   private, no limits set, no policies; not used by the app
-- ---------------------------------------------------------------------------

create policy profile_pics_delete_own
on storage.objects
as permissive
for delete
to authenticated
using (((bucket_id = 'profile_pics'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])));

create policy profile_pics_insert_own
on storage.objects
as permissive
for insert
to authenticated
with check (((bucket_id = 'profile_pics'::text) AND ((auth.uid())::text = (storage.foldername(name))[1]) AND (COALESCE(((metadata ->> 'size'::text))::integer, 0) <= 307200) AND (lower(COALESCE((metadata ->> 'mimetype'::text), ''::text)) = ANY (ARRAY['image/jpeg'::text, 'image/png'::text, 'image/heic'::text]))));

create policy profile_pics_read_public
on storage.objects
as permissive
for select
to public
using ((bucket_id = 'profile_pics'::text));

create policy profile_pics_update_own
on storage.objects
as permissive
for update
to authenticated
using (((bucket_id = 'profile_pics'::text) AND ((auth.uid())::text = (storage.foldername(name))[1])))
with check (((bucket_id = 'profile_pics'::text) AND ((auth.uid())::text = (storage.foldername(name))[1]) AND (COALESCE(((metadata ->> 'size'::text))::integer, 0) <= 307200) AND (lower(COALESCE((metadata ->> 'mimetype'::text), ''::text)) = ANY (ARRAY['image/jpeg'::text, 'image/png'::text, 'image/heic'::text]))));

-- ---------------------------------------------------------------------------
-- 9. Scheduled jobs (pg_cron)
-- ---------------------------------------------------------------------------

-- select cron.schedule(
--   'clear-stale-member-locations',
--   '*/15 * * * *',
--   $$select public.clear_stale_member_locations();$$
-- );

-- ---------------------------------------------------------------------------
-- 10. Realtime
-- ---------------------------------------------------------------------------

-- No table is in the supabase_realtime publication.

-- Extensions installed besides the Supabase defaults: pg_cron.
