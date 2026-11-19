import Foundation

/// Keeps the drink list on screen in step with the server. The 30-second refresh
/// only asks for drinks newer than the newest one shown, so it never sees another
/// member's edit or deletion, and it skips a drink logged by a phone whose clock
/// is behind. A slower full reload covers those. No UI, no network.
enum DrinkListReload {
  /// The list to show after a full reload, or nil when the screen should be left
  /// as it is.
  /// - Parameters:
  ///   - shownBefore: the drinks on screen when the request was sent.
  ///   - shownNow: the drinks on screen when the answer arrived.
  ///   - fetched: every drink the server returned for the lobby.
  /// The answer is dropped when the list changed while the request was in flight
  /// (a drink was added, edited or deleted on this phone, or the 30-second refresh
  /// ran): the server's answer may predate that change, and the next reload will
  /// pick up the rest.
  static func reloadedList(
    shownBefore: [LobbyDrink],
    shownNow: [LobbyDrink],
    fetched: [LobbyDrink]
  ) -> [LobbyDrink]? {
    guard shownNow == shownBefore else { return nil }
    let reloaded = fetched.sorted { $0.consumedAt < $1.consumedAt }
    let shownSorted = shownNow.sorted { $0.consumedAt < $1.consumedAt }
    guard !sameDrinks(reloaded, shownSorted) else { return nil }
    return reloaded
  }

  /// The fetched drinks that are not on screen yet. A full reload can deliver a
  /// drink before the 30-second refresh asks for it; without this it would be
  /// added twice and counted twice in the BAC.
  static func drinksNotShown(_ fetched: [LobbyDrink], shown: [LobbyDrink]) -> [LobbyDrink] {
    var knownIDs = Set(shown.map(\.id))
    return fetched.filter { knownIDs.insert($0.id).inserted }
  }

  // Same drinks with the same details; the order of drinks logged at the same
  // instant does not matter.
  private static func sameDrinks(_ lhs: [LobbyDrink], _ rhs: [LobbyDrink]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    let rhsByID = Dictionary(rhs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    guard rhsByID.count == rhs.count else { return false }
    return lhs.allSatisfy { rhsByID[$0.id] == $0 }
  }
}
