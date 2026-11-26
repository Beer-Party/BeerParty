import Foundation

/// When "Made it home" can still be sent. The host usually taps "Closing Time"
/// as the group leaves the bar, just before people walk home, so the message
/// stays possible for as long as the other phones keep reading new rows after
/// closing. No UI, no network.
enum MadeItHomeWindow {
  /// After closing, the lobby screens keep their live updates this long.
  static let liveUpdatesAfterClosing: TimeInterval = 5 * 60 * 60

  static let closedMessage = "The lobby closed more than 5 hours ago. \"Made it home\" can no longer be sent."

  /// - Parameter closedAt: when the lobby was closed, if this phone knows it.
  ///   Without it (for example after the 24-hour auto-close, which leaves no
  ///   closing note), a closed lobby counts as closed for good.
  static func canSend(isLobbyActive: Bool, closedAt: Date?, now: Date) -> Bool {
    if isLobbyActive {
      return true
    }
    guard let closedAt else { return false }
    // A closing time slightly ahead of this phone's clock still counts.
    return now.timeIntervalSince(closedAt) < liveUpdatesAfterClosing
  }
}
