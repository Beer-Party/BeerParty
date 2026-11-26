import Foundation

/// The nickname the user last joined or made a lobby with, kept on this phone
/// so "Join Lobby" and "Make Lobby" can fill it in. It is forgotten at
/// sign-out. No UI, no network.
enum LastNickname {
  static let key = "lobby.lastNickname"

  /// The saved nickname, or "" when there is none.
  static func load(from defaults: UserDefaults = .standard) -> String {
    defaults.string(forKey: key) ?? ""
  }

  /// Saves the nickname without surrounding spaces. An empty one is ignored,
  /// so it never replaces a nickname that was saved before.
  static func save(_ nickname: String, to defaults: UserDefaults = .standard) {
    let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    defaults.set(trimmed, forKey: key)
  }

  static func clear(from defaults: UserDefaults = .standard) {
    defaults.removeObject(forKey: key)
  }

  /// What the nickname field should hold when the form appears: what the user
  /// has already typed, or else the saved nickname.
  static func prefill(current: String, saved: String) -> String {
    current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? saved : current
  }
}
