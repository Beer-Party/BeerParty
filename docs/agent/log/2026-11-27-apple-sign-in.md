# 2026-11-27: issue #70 (and U5), Sign in with Apple

- Asked for in issue #70 by an owner ("other sign in methods like apple sign
  in and others"). This is the first part: Apple. U5 in the backlog is the
  same thing and is ticked.
- `LoginView` has a "Continue with Apple" button above "Continue with
  Google". It is Apple's own button (`SignInWithAppleButton`), white, the
  same width as the Google one, and like it only usable once the four
  confirmations are switched on.
- How it works: Apple signs the user in on the phone with Face ID and hands
  the app an identity token. The app passes it to Supabase
  (`signInWithIdToken`), which checks it and opens the session. From there
  on nothing differs from Google: `AuthViewModel` hears about the session,
  and a new user is sent to profile setup. No browser sheet, no redirect.
- `AppleSignIn` holds the parts without UI, with tests: the one-time nonce
  that ties Apple's token to this attempt and its SHA-256, telling "the user
  closed the sheet" (no message) from a real failure, reading the token.
- `BeerParty.entitlements` gets `com.apple.developer.applesignin`. AGENT.md
  allows an entitlement change when an owner's agent-queue issue asks for
  it; without it Apple refuses every attempt. No new dependency (the
  Supabase package already has `signInWithIdToken`; hashing is CryptoKit).
- `README.md`: the Supabase and signing steps below.
- Not done, for later runs under #70: other methods (email with a one-time
  code is the usual third one). Please say in the issue which ones you want.
  Also not done: unlinking or deleting an account (S7).
- Things to know:
  - A person who signs in with Google one day and Apple the next gets the
    same account only if both use the same, verified email address. With
    Apple's "Hide My Email" it is a second account with its own profile.
  - Apple gives the name only at the very first sign-in; the app does not
    use it.
- Tests: `AppleSignInTests`.
- Verified: build and unit tests in CI (which builds without signing, so it
  does not check the capability). The sign-in itself cannot be tried in CI.
- Human must do, before this works:
  1. Supabase dashboard, Authentication, Sign In / Providers, Apple: switch
     it on and enter `com.akselpaul.BeerParty` under "Client IDs". Leave the
     secret key empty.
  2. Xcode, target BeerParty, Signing & Capabilities: "Sign in with Apple"
     should now be listed. With automatic signing Xcode adds it to the App ID
     at the next build. This capability needs a paid Apple Developer team; a
     free personal team cannot sign the app once this is merged.
- Human check on a device:
  - Login screen: both buttons are greyed until the four switches are on,
    and everything fits on the smallest phone you have (the screen does not
    scroll).
  - "Continue with Apple" as a new user: Apple's sheet, then profile setup,
    then the hub.
  - Sign out, "Continue with Apple" again: straight to the hub.
  - Open Apple's sheet and close it: no error line.
  - "Continue with Google" still works.
- Backlog: U5 ticked (checkbox only).
