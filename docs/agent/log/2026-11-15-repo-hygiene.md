# 2026-11-15: Q7, repo hygiene

- Stopped tracking the two `xcuserdata` files (one person's Xcode window and
  scheme-order settings). The shared `BeerParty` scheme that CI builds is in
  `xcshareddata` and stays tracked.
- `.gitignore` now also covers `xcuserdata/`, `.DS_Store`, DerivedData and
  other build output, SwiftPM working folders and the Supabase CLI's local
  state. `Secrets.xcconfig` and `.env` were already ignored.
- Added `README.md`: what the app is, the folders, how to create
  `Secrets.xcconfig` (including the `$()` needed in the URL), signing and the app
  group, Google sign-in redirect, where the schema and migrations are, how tests
  and CI run, and how the daily agent works.
- No Swift, project file, signing or build setting changed.
- Verified: build and unit tests in CI, which confirms the build does not need
  the untracked files. The README's statements were checked against the code
  (`Supabase.swift`, `LoginView.swift`, the entitlements, `ci.yml`), not against
  a fresh machine.
- Human check: after pulling, git removes the two `xcuserdata` files from Aksel's
  working copy; Xcode recreates them on next open and they stay untracked. Read
  the README once and correct anything that does not match how you actually set
  the project up (the Google provider steps in particular).
