# 2026-11-27: B9b, the database refuses absurd drink volumes and ABV

- New file `supabase/migrations/20261127110000_drinks_volume_abv_limits.sql`.
  It adds one check to `public.drinks`: volume 0 to 2000 ml, ABV 0 to 100,
  the same limits the app has had since B9 (`DrinkInputLimits`). Until now a
  modified client or an old app version could still save 33000 ml or ABV 400
  and distort the BAC shown on every phone in the lobby.
- The system-event rows (0 ml, 0 %) pass. Rows without a volume or ABV pass
  as before.
- Existing rows are not changed and cannot make the file fail: the check is
  added as `NOT VALID` (it holds for every row saved or changed from then
  on), and a last step tries to confirm it for the old rows. If an old row is
  outside the limits, that step is skipped with a notice.
- No app change. The app already stays within these limits; if the database
  refuses a drink, the user sees the general "Couldn't add the drink" line.
- Not part of this: B28 (whole millilitres, ABV at most 99.99). The column
  types stay as they are.
- Verified: the file was run against a local Postgres built from
  `supabase/schema.sql` (not the live project): it applies, applies a second
  time, accepts 0/0, 2000/99.99 and empty values, refuses 2001 ml, -1 ml and
  a negative ABV; with an old row of 33000 ml already in the table it still
  applies and refuses new rows like it. CI does not run SQL.
- Human must do: after merging, run the file in the Supabase SQL editor, then
  tick its line in section 0 of the backlog. If the editor shows the notice
  about an older drink, nothing more is needed.
- Backlog: B9b ticked; the file is listed in section 0 as waiting.
