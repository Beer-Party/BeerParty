import Foundation

/// What "Made it home" does to location sharing. Friends want to know that a
/// member arrived, not where the member lives: with sharing left on, the pin
/// the whole lobby sees would mark the member's home. So a sent "Made it home"
/// ends sharing for the rest of this visit to the lobby screen. The saved
/// profile setting stays as it is; switching the toggle off and on shares
/// again. No UI, no network.
enum MadeItHomeSharing {
  static let pausedHint =
    "Not shared since you made it home. Switch off and on to share again."

  /// Whether a successful "Made it home" has sharing to end.
  static func endsSharing(wantsSharing: Bool, pausedAfterHome: Bool) -> Bool {
    wantsSharing && !pausedAfterHome
  }

  /// The line for the sender. The other phones show the first sentence only.
  static func confirmation(nickname: String, endedSharing: Bool) -> String {
    let arrived = "\(nickname) is safely at the fortress of dreams."
    return endedSharing ? "\(arrived) Your location is no longer shared." : arrived
  }

  /// The toggle still says "on" (it shows the saved setting), so a line under
  /// it says that nothing is shared at the moment.
  static func showsPausedHint(wantsSharing: Bool, pausedAfterHome: Bool) -> Bool {
    wantsSharing && pausedAfterHome
  }
}
