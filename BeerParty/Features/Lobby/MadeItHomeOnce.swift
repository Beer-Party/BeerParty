import Foundation

/// "Made it home" is said once per lobby. Every further one would announce
/// "... is safely at the fortress of dreams." again on every phone, so after
/// the first the button gives way to a plain line. No UI, no network.
enum MadeItHomeOnce {
  /// Shown in place of the button.
  static let sentLine = "You made it home"

  /// True when the lobby's rows hold a "made it home" row written by this
  /// user. `rows` is everything the lobby load returns, the system-event rows
  /// included. The row's own user id counts, not the nickname in its name:
  /// nicknames can change and two members can share one. False while the user
  /// is not known.
  static func hasSent(in rows: [LobbyDrink], userID: UUID?) -> Bool {
    guard let userID else { return false }
    return rows.contains { row in
      row.userId == userID && LobbySystemEvent.madeItHomeNickname(from: row) != nil
    }
  }
}
