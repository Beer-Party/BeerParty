# 2026-11-28: issue #70, sign in with an email code

- Asked for in issue #70 by an owner ("other sign in methods like apple sign
  in and others"). Apple came on 2026-11-27 (#76). This is the second part:
  an email address and a one-time code, the usual third method, for people
  who want neither Google nor Apple. Nobody answered the question in the
  last log about which methods are wanted, so this is the agent's choice;
  say so in the issue if it should be another one.
- `LoginView` has a small "Continue with email" line under "Continue with
  Google". Like the two buttons it is only usable once the four
  confirmations are switched on. It is a text line, not a third big button,
  because the login screen does not scroll. Nothing else on that screen
  changed.
- It opens a sheet, `EmailSignInView`, in the new look (glass pane, glossy
  main button):
  1. Type the address, "Send code". Supabase mails a code
     (`signInWithOTP`).
  2. Type the code, "Sign in". Supabase checks it (`verifyOTP`) and opens
     the session. The sheet closes, and from there on nothing differs from
     Google and Apple: `AuthViewModel` hears about the session and a new
     user is sent to profile setup.
  "Send again" is off for 60 seconds after a code was sent (Supabase would
  refuse it anyway). "Use another address" goes back to step 1. The code
  field takes the code from the keyboard's suggestion when iOS offers it.
- `EmailSignIn` holds the parts without UI, with tests: tidying and
  checking the address (only to catch slips; Supabase decides), reducing
  what was typed or pasted to the digits of the code, when a code is long
  enough to send (6 to 10 digits, the range the Supabase setting allows),
  and the seconds until "Send again".
- No new dependency (the Supabase package already has both calls), no
  entitlement, no database change.
- `README.md`: the Supabase steps below.
- Decisions made, say so if they should differ:
  - A new address makes a new account straight away, as with Google and
    Apple. There is no separate "sign up".
  - A wrong or expired code shows one sentence ("That code didn't work.
    Check it, or ask for a new one."), whatever the server said. Being
    offline gets the usual connection message.
  - The app does not use the link in the mail, only the code. Making the
    link open the app would need a redirect address and more setup.
- Things to know:
  - A person who signs in with Google one day and with the same address by
    code the next gets the same account (Supabase joins sign-ins with the
    same verified address). With another address it is a second account.
  - Not done under #70: anything further (phone number, password). Deleting
    an account is S7.
- Tests: `EmailSignInTests`.
- Verified: build and unit tests in CI. Sending and checking a code cannot
  be tried in CI, and nobody has seen the sheet on a screen yet.
- Human must do, before this works (Supabase dashboard, Authentication):
  1. Email provider switched on (it is by default).
  2. Email templates "Magic Link" and "Confirm signup": put `{{ .Token }}`
     in the text, for example "Your BeerParty code is {{ .Token }}". The
     default templates only have a link. Until this is done, the button
     sends a mail with a link that this app cannot use, and nobody can sign
     in this way. Do this before, or right after, merging.
  3. Before release: a real mail sender under SMTP settings. The built-in
     one only delivers a few mails per hour.
- Human check on a device:
  - Login screen: "Continue with email" is greyed until the four switches
    are on, is readable on the yellow background, and everything still fits
    on the smallest phone you have.
  - With a new address: the mail arrives with a code; typing it leads to
    profile setup, then the hub.
  - Sign out, sign in again with the same address: straight to the hub.
  - A wrong code: the sentence above, and a second try with the right code
    works.
  - "Send again" counts down from 60 and then sends a new mail; "Use
    another address" goes back; "Cancel" closes the sheet.
  - "Continue with Apple" and "Continue with Google" still work.
- Backlog: nothing to tick; the work is tracked in issue #70.
