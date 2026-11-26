# 2026-11-26: B23, the profile refuses impossible weights and ages

- Before: `ProfileSetupView` only checked weight > 0 and age > 0. A slip such
  as 750 instead of 75 kg was saved, and since B15 it is used: that member's
  BAC came out about ten times too low on every phone in the lobby. Age 400
  was accepted as well.
- Now: a weight outside 30 to 300 kg (66 to 661 lbs when the field is in
  pounds) or an age above 120 shows a red line under the field ("Weight must
  be between 30 and 300 kg.", "Age can be at most 120.") and "Save Profile"
  stays off. The rule is `ProfileInputLimits`, a plain function like
  `DrinkInputLimits`; the check is in the unit the user is typing in.
- Not part of this: a minimum age. The legal drinking age differs by country
  and that is an owner decision (said so in the backlog item).
- Existing profiles: nothing is changed in the database. A user whose saved
  weight is already outside the range sees the line when opening "Edit
  Profile" and has to correct it before saving again. Their BAC in lobbies
  keeps using the old value until then.
- Small edge: exactly 66 lbs shows as 29.9 kg after switching the unit and is
  then just under the kilogram limit; switching back or typing 30 fixes it.
- Tests: `ProfileInputLimitsTests` (ordinary values, the limits themselves,
  slips in both units, the unit decides, empty and zero get no message, age).
- Verified: build and unit tests in CI. Not tested on a device.
- Human check:
  - "Edit Profile", unit kg: type 750. A red line appears under the weight
    and "Save Profile" is off. Change to 75: line gone, saving works.
  - Switch the unit to lbs with 75 kg typed: the field shows 165 and no line.
    Type 20: the line names the range in lbs.
  - Type age 400: red line under the age; 30: gone.
- Backlog: B23 ticked (checkbox only).
