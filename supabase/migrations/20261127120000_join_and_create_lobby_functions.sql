-- Joining and making a lobby through database functions (backlog S11, step 1
-- of 2; also most of S2 and the rest of B10).
--
-- Today the app joins a lobby by reading public.lobbies itself (to find the
-- lobby for an invite code) and then inserting its own row into
-- public.lobby_members. For that to work, every signed-in user must be able
-- to read every open lobby (policy lobbies_select_active) and to insert a
-- member row for any lobby (policy lm_insert_self). So anyone with an account
-- and a modified client can list the open lobbies and put themselves into
-- any of them without knowing the invite code, and then read what members
-- read: live locations, drinks, and other members' profiles.
--
-- This file only ADDS two functions. It changes no table, no policy and no
-- row, and the app does not call the functions yet, so nothing changes for
-- users when it is applied:
--
--   join_lobby(p_invite_code, p_nickname)
--     Finds the open lobby with that invite code (capital and small letters do
--     not matter; a code spelled exactly as typed wins, as in the app), makes
--     the caller a member with that nickname and returns the lobby's id and
--     name. Joining again only changes the nickname. Without the right code
--     there is no way in.
--
--   create_lobby(p_name, p_invite_code, p_nickname)
--     Makes the lobby, the caller's member row (role 'admin', as the app
--     writes it) and the caller's member_state row in one step, so a failure
--     can no longer leave a lobby without members behind (B10). Refuses a
--     code another lobby already has, also when only the case differs.
--
-- Both run with the rights of their owner (security definer), check
-- auth.uid() themselves, and can be called by signed-in users only.
--
-- What comes after this file:
--   1. A pull request that makes the app call these two functions (it keeps
--      writing lobby_member_bac_params itself, which the existing policies
--      allow for members).
--   2. Once that app version is on the phones: a second migration that drops
--      lm_insert_self, ms_insert_self and lobbies_select_active. Only that
--      step closes the hole; this one prepares it.
--
-- The older functions join_lobby(text) and create_lobby(text) (unused by the
-- app) are left alone; they have different arguments, so both can exist. They
-- can be dropped in the second migration.
--
-- Errors carry a code the app can tell apart:
--   28000  not signed in
--   22023  nickname, lobby name or invite code not acceptable
--   P0002  no open lobby has that invite code
--   P0003  several open lobbies have that code (they differ only in case)
--   23505  the invite code is already in use (create_lobby)
--
-- Not applied automatically. An owner runs this in the Supabase SQL editor (or
-- `supabase db push`). Safe to run more than once.

create or replace function public.join_lobby(p_invite_code text, p_nickname text)
returns table (lobby_id uuid, lobby_name text)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_user_id uuid := auth.uid();
  v_code text := btrim(coalesce(p_invite_code, ''));
  v_nickname text := btrim(coalesce(p_nickname, ''));
  v_matches integer;
  v_lobby_id uuid;
  v_lobby_name text;
begin
  if v_user_id is null then
    raise exception 'Not signed in.' using errcode = '28000';
  end if;
  if v_nickname = '' or length(v_nickname) >= 30 then
    raise exception 'A nickname needs 1 to 29 characters.' using errcode = '22023';
  end if;
  if v_code = '' then
    raise exception 'An invite code is needed.' using errcode = '22023';
  end if;

  -- A code spelled exactly as typed wins over ones that differ in case.
  select count(*) into v_matches
  from public.lobbies l
  where l.invite_code = v_code and l.is_active;

  if v_matches = 1 then
    select l.id, l.name into v_lobby_id, v_lobby_name
    from public.lobbies l
    where l.invite_code = v_code and l.is_active;
  else
    select count(*) into v_matches
    from public.lobbies l
    where lower(l.invite_code) = lower(v_code) and l.is_active;

    if v_matches = 0 then
      raise exception 'No open lobby has that invite code.' using errcode = 'P0002';
    elsif v_matches > 1 then
      raise exception 'Several lobbies share that invite code.' using errcode = 'P0003';
    end if;

    select l.id, l.name into v_lobby_id, v_lobby_name
    from public.lobbies l
    where lower(l.invite_code) = lower(v_code) and l.is_active;
  end if;

  -- Joining again keeps the role (the host stays 'admin') and takes the new
  -- nickname.
  insert into public.lobby_members as m (lobby_id, user_id, nickname, role)
  values (v_lobby_id, v_user_id, v_nickname, 'guest')
  on conflict on constraint lobby_members_pkey
  do update set nickname = excluded.nickname;

  insert into public.member_state (lobby_id, user_id)
  values (v_lobby_id, v_user_id)
  on conflict on constraint member_state_pkey do nothing;

  return query select v_lobby_id, v_lobby_name;
end;
$$;

create or replace function public.create_lobby(p_name text, p_invite_code text, p_nickname text)
returns table (lobby_id uuid, lobby_name text)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_user_id uuid := auth.uid();
  v_name text := btrim(coalesce(p_name, ''));
  v_code text := btrim(coalesce(p_invite_code, ''));
  v_nickname text := btrim(coalesce(p_nickname, ''));
  v_lobby_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not signed in.' using errcode = '28000';
  end if;
  if v_name = '' then
    raise exception 'A lobby needs a name.' using errcode = '22023';
  end if;
  if v_nickname = '' or length(v_nickname) >= 30 then
    raise exception 'A nickname needs 1 to 29 characters.' using errcode = '22023';
  end if;
  -- The app's minimum.
  if length(v_code) < 4 then
    raise exception 'An invite code needs at least 4 characters.' using errcode = '22023';
  end if;

  -- What an earlier failed attempt of this user left behind (a lobby of their
  -- own with this code and no members) is removed first, as the app does.
  delete from public.lobbies l
  where lower(l.invite_code) = lower(v_code)
    and l.created_by = v_user_id
    and not exists (
      select 1 from public.lobby_members m where m.lobby_id = l.id
    );

  if exists (
    select 1 from public.lobbies l where lower(l.invite_code) = lower(v_code)
  ) then
    raise exception 'That invite code is already in use.' using errcode = '23505';
  end if;

  insert into public.lobbies as l (created_by, name, invite_code, is_active)
  values (v_user_id, v_name, v_code, true)
  returning l.id into v_lobby_id;

  insert into public.lobby_members (lobby_id, user_id, nickname, role)
  values (v_lobby_id, v_user_id, v_nickname, 'admin');

  insert into public.member_state (lobby_id, user_id)
  values (v_lobby_id, v_user_id)
  on conflict on constraint member_state_pkey do nothing;

  return query select v_lobby_id, v_name;
end;
$$;

-- Signed-in users only. (Supabase gives new functions to anon as well unless
-- this is taken back.)
revoke all on function public.join_lobby(text, text) from public, anon;
revoke all on function public.create_lobby(text, text, text) from public, anon;
grant execute on function public.join_lobby(text, text) to authenticated;
grant execute on function public.create_lobby(text, text, text) to authenticated;
