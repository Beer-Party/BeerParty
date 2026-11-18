import Foundation

/// "Made it home", "lobby closed" and "motion due" travel as rows in `drinks`
/// whose name starts with a magic prefix (backlog item B5 moves them to their own
/// table). This reads those rows. No UI, no network.
enum LobbySystemEvent {
  /// True when the row is one of the three events and not a real drink.
  static func isSystemEvent(_ drink: LobbyDrink) -> Bool {
    motionArrivalTarget(from: drink) != nil ||
      madeItHomeNickname(from: drink) != nil ||
      closedAtTime(from: drink) != nil
  }

  /// The nickname in a "made it home" row ("Member" when it is empty), or nil
  /// when the row is something else.
  static func madeItHomeNickname(from drink: LobbyDrink) -> String? {
    guard drink.name.hasPrefix(LobbyBackendService.madeItHomeDrinkPrefix) else { return nil }
    let rawNickname = String(drink.name.dropFirst(LobbyBackendService.madeItHomeDrinkPrefix.count))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return rawNickname.isEmpty ? "Member" : rawNickname
  }

  /// When the lobby was closed, from a "lobby closed" row, or nil when the row is
  /// something else. The row's name is "<prefix><ISO time>|<who closed it>"; when
  /// the time is missing or unreadable, the row's own timestamp is used.
  static func closedAtTime(from drink: LobbyDrink) -> Date? {
    guard drink.name.hasPrefix(LobbyBackendService.lobbyClosedDrinkPrefix) else { return nil }
    let raw = String(drink.name.dropFirst(LobbyBackendService.lobbyClosedDrinkPrefix.count))
    let isoString = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
    guard !isoString.isEmpty else { return drink.consumedAt }
    let isoWithFractions = ISO8601DateFormatter()
    isoWithFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = isoWithFractions.date(from: isoString) {
      return parsed
    }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: isoString) ?? drink.consumedAt
  }

  /// Where a passed motion sends the lobby, from a "motion due" row, or nil when
  /// the row is something else. The row's name is "<prefix><motion id>|<target>";
  /// a row without the "|" is not treated as an event.
  static func motionArrivalTarget(from drink: LobbyDrink) -> String? {
    guard drink.name.hasPrefix(LobbyBackendService.motionArrivedDrinkPrefix) else { return nil }
    let raw = String(drink.name.dropFirst(LobbyBackendService.motionArrivedDrinkPrefix.count))
    let segments = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
    guard segments.count == 2 else { return nil }
    let target = String(segments[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    return target.isEmpty ? "the destination" : target
  }
}
