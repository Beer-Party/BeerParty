import Foundation

/// How long the names that people type may be. A name is shown on every phone
/// in the lobby (the "Live BAC" list, the graph labels, the status banner, the
/// Lock Screen), so a pasted sentence breaks those layouts for everybody.
/// Lengths are counted after trimming, in characters as the user sees them
/// (an emoji is one). No UI, no network.
enum NameLimits {
  enum Kind: Equatable, CaseIterable {
    case nickname
    case lobbyName
    case drinkName
    case motionDestination

    /// The longest allowed length. The database refuses a nickname of 30 or
    /// more (`lobby_members_nickname_check`); 24 stays well below that.
    var maxLength: Int {
      switch self {
      case .nickname: return 24
      case .lobbyName: return 40
      case .drinkName: return 40
      case .motionDestination: return 60
      }
    }

    /// The name of the field, worded to start a sentence.
    var label: String {
      switch self {
      case .nickname: return "Nickname"
      case .lobbyName: return "Lobby name"
      case .drinkName: return "Drink name"
      case .motionDestination: return "Destination"
      }
    }
  }

  /// The text without spaces and line breaks around it: what is saved.
  static func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Why the text is too long, as a sentence for the user, or nil when it
  /// fits. An empty text is not judged here.
  static func message(for text: String, kind: Kind) -> String? {
    let length = trimmed(text).count
    guard length > kind.maxLength else { return nil }
    return "\(kind.label) can be at most \(kind.maxLength) characters (now \(length))."
  }

  static func allows(_ text: String, kind: Kind) -> Bool {
    message(for: text, kind: kind) == nil
  }

  /// Throws `NameLimitError` when the text is too long. For the service
  /// layer, which checks again whatever the screen allowed.
  static func check(_ text: String, kind: Kind) throws {
    guard allows(text, kind: kind) else {
      throw NameLimitError(kind: kind)
    }
  }
}

/// A name was longer than `NameLimits` allows.
struct NameLimitError: LocalizedError, Equatable {
  let kind: NameLimits.Kind

  var errorDescription: String? {
    "\(kind.label) can be at most \(kind.maxLength) characters."
  }
}
