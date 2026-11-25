# 2026-11-25: "Join Lobby" and "Make Lobby" remember your nickname

- One of five UI changes an owner asked for in the agent chat on 2026-11-25
  (a one-off request, not a backlog item, so `BACKLOG.md` is not changed).
- Before: the nickname had to be typed again for every lobby, on both forms.
- Now: after a lobby is joined or made, the nickname is kept on the phone and
  filled in the next time either form opens. It can be changed as before; the
  new one is remembered instead. With the nickname filled in, joining a lobby
  is: type the code, tap "Join".
- Where it is kept: in the app's own settings on this phone (`UserDefaults`),
  not on the server and not in the shared app group. It is removed at
  sign-out, so the next person to sign in on the phone is not offered it.
- Code: `LastNickname` (`BeerParty/Features/Lobby/LastNickname.swift`) loads,
  saves and clears it; `LobbyLoginView` and `MakeLobbyView` fill the field when
  they appear and save after success; `AuthViewModel` clears it when the user
  is signed out.
- Unit tests in `LastNicknameTests`: load, save (trimmed, empty ignored, newest
  wins), clear, and what the field shows when the form appears.
- Verified: build and unit tests in CI. Not tested on a device.
- Human check:
  - Join or make a lobby as "Anna". Open "Join Lobby" again: the nickname
    field already says "Anna". The same in "Make Lobby".
  - Change it to "Annie" and join another lobby: "Annie" is offered next time.
  - "Join" stays grey until a code is typed, also with the nickname filled in.
  - Sign out and in again: the nickname field is empty.
