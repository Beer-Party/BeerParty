-- Limits for a drink's volume and ABV in the database (backlog B9b).
--
-- The app refuses a drink above 2000 ml or above 100 % (DrinkInputLimits,
-- since B9), but the database accepts anything a client sends: a modified
-- client, or an old version of the app, can still save 33000 ml or ABV 400,
-- which gives an absurd BAC on every phone in the lobby. This adds the same
-- limits as a check on public.drinks:
--
--   volume_ml  0 to 2000
--   abv        0 to 100
--
-- The "made it home", "lobby closed" and "motion due" rows are stored as
-- drinks with 0 ml and 0 % and pass. A row without a volume or without an ABV
-- passes as before (both columns allow null).
--
-- Rows that are already in the table are not touched. The constraint is added
-- as NOT VALID, so it holds for every row saved or changed from now on, and
-- the last statement then tries to confirm it for the old rows too. If an old
-- row is outside the limits, that step is skipped with a notice and nothing
-- else changes; the old row stays as it is (editing it would need values
-- within the limits).
--
-- Not applied automatically. An owner runs this in the Supabase SQL editor (or
-- `supabase db push`). Safe to run more than once.

alter table public.drinks
  drop constraint if exists drinks_volume_abv_within_limits;

alter table public.drinks
  add constraint drinks_volume_abv_within_limits
  check (
    volume_ml >= 0 and volume_ml <= 2000
    and abv >= 0 and abv <= 100
  )
  not valid;

do $$
begin
  alter table public.drinks
    validate constraint drinks_volume_abv_within_limits;
exception
  when check_violation then
    raise notice 'drinks_volume_abv_within_limits: at least one older drink is outside the limits. The limits apply to new and changed drinks only.';
end;
$$;
