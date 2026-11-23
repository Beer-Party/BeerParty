import Foundation

/// The rules behind the "Drink History" section of the lobby screen: which
/// drinks it lists and which of them can still be changed. Plain functions with
/// no UI, moved out of `LobbyView`.
enum DrinkHistory {
  /// A drink can be edited or deleted this long after it was added.
  static let editWindow: TimeInterval = 15 * 60

  /// The user's own drinks, newest first. Empty while the user is not known.
  static func ownDrinks(in drinks: [LobbyDrink], userID: UUID?) -> [LobbyDrink] {
    guard let userID else { return [] }
    return drinks
      .filter { $0.userId == userID }
      .sorted { $0.consumedAt > $1.consumedAt }
  }

  /// True while the user may edit or delete the drink: the lobby is open, the
  /// drink is the user's own, it is a real drink and not a system-event row,
  /// and it was added no more than 15 minutes ago.
  static func canModify(
    _ drink: LobbyDrink,
    currentUserID: UUID?,
    isLobbyActive: Bool,
    now: Date
  ) -> Bool {
    guard isLobbyActive, currentUserID == drink.userId, !LobbySystemEvent.isSystemEvent(drink) else {
      return false
    }
    let elapsed = now.timeIntervalSince(drink.consumedAt)
    return elapsed >= 0 && elapsed <= editWindow
  }
}
