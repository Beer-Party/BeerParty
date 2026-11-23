import Foundation

/// iOS reports a new position only after about 25 metres of movement, and the
/// map hides pins older than five minutes. A member who stays in one place
/// would vanish from the map, so the last known position is sent again from
/// time to time while sharing is on.
enum LocationResend {
  /// Well under the map's five-minute limit, so one missed send does no harm.
  static let interval: TimeInterval = 2 * 60

  /// True when the last known position should be uploaded again now.
  ///
  /// - Parameters:
  ///   - isSharing: sharing is on and the lobby is still live.
  ///   - hasLocation: a position is known since sharing was last started.
  ///   - lastUploadAt: when a position was last saved; nil if none was yet
  ///     (for example the first upload failed).
  static func isDue(
    isSharing: Bool,
    hasLocation: Bool,
    lastUploadAt: Date?,
    now: Date
  ) -> Bool {
    guard isSharing, hasLocation else { return false }
    guard let lastUploadAt else { return true }
    return now.timeIntervalSince(lastUploadAt) >= interval
  }
}
