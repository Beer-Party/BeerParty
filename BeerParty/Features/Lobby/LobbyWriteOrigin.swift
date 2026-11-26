import Foundation

/// What set off a write from the lobby screen to the server, and whether a
/// failure of it is worth a line in the status banner.
///
/// A message is only useful for something the user just did and can try
/// again. The timed and automatic writes are repeated anyway; while the phone
/// has no signal their messages would come back every few minutes and
/// replace the line about what the user did ("Added Beer.").
enum LobbyWriteOrigin: Equatable {
  /// The user just did something: added a drink, switched sharing on.
  case userAction
  /// One of the screen's timers.
  case timer
  /// The system, for example a new position while walking.
  case automatic

  var reportsFailure: Bool {
    self == .userAction
  }

  /// The BAC write is forced after the user's own actions (a drink added,
  /// changed or deleted, the lobby opened or refreshed); otherwise it is the
  /// five-minute timer.
  static func ofBACWrite(forced: Bool) -> LobbyWriteOrigin {
    forced ? .userAction : .timer
  }

  /// Only the first upload after sharing was switched on counts as the
  /// user's own; later ones are new positions from the system or the timed
  /// resend.
  static func ofLocationUpload(sharingJustSwitchedOn: Bool, isResend: Bool) -> LobbyWriteOrigin {
    if sharingJustSwitchedOn {
      return .userAction
    }
    return isResend ? .timer : .automatic
  }
}
