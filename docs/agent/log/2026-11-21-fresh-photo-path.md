# 2026-11-21: B14, a changed profile photo shows up at once

- The photo was always uploaded to `<user id>/avatar.jpg`, so its public link
  never changed. Phones and the storage cache keep pictures by link, so the user
  and the other lobby members went on seeing the old photo, often for hours.
- Each upload now goes to its own name in the same folder,
  `<user id>/avatar-<seconds since 1970>.jpg`, and that path is saved in
  `profiles.profile_pic_path` as before. Every screen builds the link from that
  column, so the hub, the profile editor and the map all pick up the new photo.
- After the profile row is saved, the photo it pointed at before is deleted from
  storage (best effort; a failure is not shown). Only a file inside the user's
  own folder is ever deleted.
- The bucket's rules are not in the repo (S1), and the database could not be
  read from this run. If an upload under a new name is refused, the app uploads
  to the old `avatar.jpg` path as before, so saving a profile cannot break; in
  that case the old caching behaviour stays.
- Known gap: if the upload works but saving the profile row then fails, the new
  file stays in storage unused until the next successful change replaces it.
- The path naming and the "which old file to delete" rule are in
  `ProfilePhotoPath`, with unit tests in `ProfilePhotoPathTests`.
- Verified: build and unit tests in CI. Not tested on a device, and not against
  the real bucket.
- Human check: (1) with a profile photo set, open the profile editor, pick a
  different photo and save: the hub screen shows the new photo straight away.
  (2) On a second phone in the same lobby with location sharing on, the map pin
  shows the new photo after its next refresh. (3) In Supabase, Storage,
  `profile_pics`, your user folder: there is one file, named
  `avatar-<number>.jpg`. If the file is still `avatar.jpg`, the bucket refused
  the new name: tell the agent, and S1 (bucket rules in the repo) comes first.
  If there are two files, the bucket does not let the app delete: the same.
- Backlog: B14 is one of the items proposed in pull request #35, which is not
  merged yet, so there is no line on `main` to tick and `BACKLOG.md` is not
  changed here (adding the line would conflict with #35). Once #35 is merged, a
  later run ticks B14.
