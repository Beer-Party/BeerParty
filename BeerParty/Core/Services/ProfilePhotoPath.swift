import Foundation

/// Where a user's profile photo lives in the `profile_pics` bucket.
///
/// The photo used to be saved at the same path every time, so its public link
/// never changed and phones and the storage cache kept showing the old picture.
/// Each upload now gets its own file name inside the user's folder.
enum ProfilePhotoPath {
  /// The single path every photo used before. Still used when an upload under a
  /// new name is refused.
  static func legacyPath(userID: UUID) -> String {
    "\(userID.uuidString)/avatar.jpg"
  }

  /// A path that differs for every upload: `<user id>/avatar-<seconds>.jpg`.
  static func newPath(userID: UUID, at date: Date) -> String {
    let seconds = Int(date.timeIntervalSince1970.rounded(.down))
    return "\(userID.uuidString)/avatar-\(seconds).jpg"
  }

  /// The old file to delete once the profile points at `new`, or nil when there
  /// is nothing to delete. Only a file in the user's own folder is ever named.
  static func replacedPath(old: String?, new: String?, userID: UUID) -> String? {
    guard let old, !old.isEmpty, let new, !new.isEmpty, old != new else { return nil }
    let folder = "\(userID.uuidString)/".lowercased()
    guard old.lowercased().hasPrefix(folder) else { return nil }
    return old
  }
}
