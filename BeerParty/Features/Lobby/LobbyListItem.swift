import Foundation

/// One row of "Your Lobbies" on the hub screen.
struct LobbyListItem: Identifiable {
  let destination: LobbyDestination
  let isActive: Bool
  let memberCount: Int
  let createdAt: Date?

  var id: UUID { destination.lobbyID }

  /// Open lobbies first, then newest first. A lobby with no known date counts
  /// as the oldest.
  static func sorted(_ items: [LobbyListItem]) -> [LobbyListItem] {
    items.sorted { lhs, rhs in
      if lhs.isActive != rhs.isActive {
        return lhs.isActive && !rhs.isActive
      }
      return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
    }
  }

  /// What the list shows after a reload. A reload that failed (nil) keeps the
  /// rows already on screen, so one bad request does not lock the user out of
  /// their lobbies.
  static func afterReload(shown: [LobbyListItem], loaded: [LobbyListItem]?) -> [LobbyListItem] {
    guard let loaded else { return shown }
    return sorted(loaded)
  }
}
