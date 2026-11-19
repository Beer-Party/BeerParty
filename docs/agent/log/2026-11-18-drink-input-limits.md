# 2026-11-18: B9, upper limits on drink volume and ABV

- Volume only had to be above 0 and ABV 0 or more, so a slip such as ABV 400 or
  33000 ml was saved, gave an absurd BAC and was synced to the whole lobby.
- New `DrinkInputLimits` (`BeerParty/Features/Lobby/DrinkInputLimits.swift`): at
  most 2000 ml and at most 100 % ABV. 2000 ml is the example from the backlog; it
  is one constant if you want another number.
- Add form and edit sheet: when a typed value is over a limit, a red line under
  the fields says which ("Volume can be at most 2000 ml.", "ABV can be at most
  100 %.") and "Add Drink" / "Save" stay disabled.
- `insertDrink` and `updateDrink` in `LobbyBackendService` refuse such values too
  (`DrinkMutationError.outOfRange`, shown with the same sentence), so no other
  path in the app can save them.
- Not done here: the Lock Screen quick-add in the widget target writes its own
  rows. It only sends the fixed presets and the custom preset, and the custom
  preset is saved from a manual drink that has already passed these limits.
- Still open from B9: the database check constraint. It needs the `drinks` table
  definition in the repo, so it waits for S1. Until then a modified client could
  still write any value.
- Drinks already saved with larger values are not touched. Opening one in the
  edit sheet shows the message until the value is corrected.
- Unit tests in `DrinkInputLimitsTests`.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check: in a lobby type volume 33000 and ABV 5: a red line appears and
  "Add Drink" is disabled; change the volume to 330 and it works. Type ABV 400:
  same. Add a normal drink, tap Edit and set ABV to 400: "Save" is disabled and
  the red line shows inside the sheet. The four quick-add buttons still work.
