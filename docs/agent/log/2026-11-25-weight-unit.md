# 2026-11-25: U11, the weight field starts in the unit of the phone's region

- One of five UI changes an owner asked for in the agent chat on 2026-11-25;
  this one is backlog item U11.
- Before: the profile's weight field always started as "Weight (lbs)". A user
  in Europe who typed 75 without noticing was saved as 75 lbs (34 kg), and
  since B15 that makes their BAC about 40 % too high. "Edit Profile" also
  showed a weight entered in kilograms converted to pounds every time.
- Now: the field starts in kilograms, except on phones whose region uses the
  US or UK measurement system, where it starts in pounds. The lbs/kg switch is
  still there. "Edit Profile" shows the saved weight in that same unit.
- Nothing changes in the database: the weight is still saved in pounds.
- Users who already saved a wrong weight are not corrected by this. Someone
  who typed kilograms into the pounds field has to open "Edit Profile" and
  type the weight again (a saved weight under about 90 lbs is a hint).
- Code: `WeightUnitPreference` (`BeerParty/Core/Services/`) decides the
  starting unit and formats the saved weight; `ProfileSetupView` uses both.
- Unit tests in `WeightUnitPreferenceTests`: which regions get which unit, the
  text shown for a saved weight in each unit, and that what is shown reads
  back as the same weight.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check:
  - Phone region Norway or Germany: a new profile, and "Edit Profile", show
    "Weight (kg)" with kg selected. A profile saved as 75 kg shows 75.0.
  - Phone region United States: both show "Weight (lbs)".
  - Switching lbs/kg still converts the number; saving and reopening shows
    the same weight.
- Backlog: ticks U11.
