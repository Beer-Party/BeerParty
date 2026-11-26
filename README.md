# BeerParty

An iOS app for a night out with friends. Everyone joins a lobby with an invite
code, logs their drinks, and the lobby shows each member's estimated blood
alcohol over time, where people are on a map, and votes ("motions") on where to
go next. Drinks can also be added from the Lock Screen.

The estimates are not medically accurate. Do not use them to decide whether
someone can drive.

- `BeerParty/`: the SwiftUI app
- `BeerPartyWidget/`: the widget extension (Lock Screen quick add, Live Activity)
- `BeerPartyTests/`, `BeerPartyUITests/`: tests
- `supabase/migrations/`: database changes, applied by hand (see below)
- `docs/agent/`: rules, backlog and log of the daily improvement agent

## Requirements

- A recent Xcode with the iOS 26 SDK. The deployment target is iOS 26.2.
- A Supabase project (the backend), with Google sign-in enabled.

The only dependency is [supabase-swift](https://github.com/supabase-community/supabase-swift),
which Xcode fetches through Swift Package Manager when the project is opened.

## Setup

1. Clone the repo and open `BeerParty.xcodeproj`.
2. Create `BeerParty/Config/Secrets.xcconfig` with the project's URL and anon
   (publishable) key, both from the Supabase dashboard under Project Settings:

   ```
   SUPABASE_URL = https:/$()/YOUR-PROJECT-REF.supabase.co
   SUPABASE_ANON_KEY = YOUR-ANON-KEY
   ```

   The `$()` is needed: without it xcconfig reads `//` as the start of a comment
   and the URL is cut off. The file is git-ignored. Never commit it, and never
   put the service-role key in the app.
3. Pick the `BeerParty` scheme and run on a simulator or a phone.

If the file is missing or still has placeholder text, the app stops at launch
with a message naming the missing value.

To run on a phone, choose your own team under Signing & Capabilities for both
the app and the widget extension. Both use the app group
`group.com.beerparty.shared`, which is how the Lock Screen buttons reach the
lobby.

## Supabase

- **Sign-in** is Google through Supabase Auth. In the Supabase dashboard, enable
  the Google provider and add `beerparty://login-callback` to the allowed
  redirect URLs.
- **Schema.** `supabase/schema.sql` is a snapshot of the live database
  (tables, functions, triggers, access rules, storage rules), taken by reading
  the project. It is for reading and review; do not run it. It goes out of
  date when a new migration is applied, until it is taken again.
  `supabase_motions.sql` is the older, original script for the motions tables.
- **Migrations** live in `supabase/migrations/`. Nothing applies them
  automatically: an owner runs each new file in the Supabase SQL editor after
  its pull request is merged. `docs/agent/BACKLOG.md` lists the ones still
  waiting.

## Tests and CI

Unit tests: Product > Test in Xcode, or

```
xcodebuild test -project BeerParty.xcodeproj -scheme BeerParty \
  -destination 'platform=iOS Simulator,name=<an installed iPhone simulator>'
```

Every pull request is built and tested by GitHub Actions
(`.github/workflows/ci.yml`) with placeholder Supabase settings, so CI never
talks to a real project. Location, the map and the Live Activity are not
covered by tests and need a check on a device.

## The daily agent

A scheduled Claude session opens small pull requests labelled `agent` against
this repo. It never pushes to `main` and never merges; an owner reviews and
merges. Its rules are in `docs/agent/AGENT.md`, its work list in
`docs/agent/BACKLOG.md`. To queue something for it, open an issue with the
`agent-queue` label.
