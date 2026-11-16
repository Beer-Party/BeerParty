import Foundation

/// Decides when the access token saved for the Lock Screen buttons must be replaced.
enum LockScreenTokenRefresh {
  /// The token to store, or nil when there is nothing new to store.
  static func replacement(stored: String?, fresh: String?) -> String? {
    guard let fresh, !fresh.isEmpty, fresh != stored else { return nil }
    return fresh
  }
}
