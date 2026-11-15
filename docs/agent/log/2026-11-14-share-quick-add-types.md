# 2026-11-14: Q5, app and widget share the quick-add types

- `BeerParty/Core/Models/LockScreenQuickAdd.swift` is now a member of the widget
  extension as well as the app. The widget's own copies of `QuickAddDrinkPreset`,
  `LobbyQuickAddContext`, `LobbyQuickAddStore` and
  `LobbyQuickAddActivityAttributes` are deleted, and the Lock Screen buttons use
  the shared presets (`.beer`, `.wine`, `.shot`, `.water`) instead of repeating
  the numbers. The two copies were identical, so nothing changes for users; a
  future change to the saved context or a preset now happens in one place.
- The target membership is one small edit to `project.pbxproj` (an exception set
  that adds that one file to `BeerPartyWidgetExtension`). No signing, bundle id,
  entitlement or dependency changes.
- Verified: CI builds the app together with the widget extension, which only
  compiles if the widget finds the shared types. One unit test pins the preset
  values to what the widget had hard-coded.
- Human check on a device: open the project in Xcode once and confirm
  `LockScreenQuickAdd.swift` shows both targets ticked under Target Membership.
  Then turn on Lock Screen Quick Add in a lobby: the Live Activity appears, and
  Beer, Wine, Shot, Water and the custom button each add the right drink.
