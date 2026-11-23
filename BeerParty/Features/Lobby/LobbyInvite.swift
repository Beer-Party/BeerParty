import Foundation

/// The text handed to the share sheet when a member shares a lobby's invite code.
enum LobbyInvite {
  static func shareMessage(lobbyName: String, inviteCode: String) -> String {
    let name = lobbyName.trimmingCharacters(in: .whitespacesAndNewlines)
    let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
    if name.isEmpty {
      return "Join my BeerParty lobby with invite code \(code)"
    }
    return "Join my BeerParty lobby \u{201C}\(name)\u{201D} with invite code \(code)"
  }

  /// The typed code as a pattern for a case-insensitive database match
  /// (`ilike`). The characters that mean something in such a pattern, `%`, `_`
  /// and the escape character `\`, are escaped so they only match themselves.
  static func caseInsensitivePattern(for inviteCode: String) -> String {
    var pattern = ""
    for character in inviteCode {
      if character == "\\" || character == "%" || character == "_" {
        pattern.append("\\")
      }
      pattern.append(character)
    }
    return pattern
  }

  /// True when two codes are the same apart from capital and small letters.
  static func isSameCode(_ lhs: String, _ rhs: String) -> Bool {
    lhs.lowercased() == rhs.lowercased()
  }

  enum Match: Equatable {
    case none
    /// The position, in the list given, of the lobby to join.
    case one(Int)
    /// More than one lobby fits and none is spelled exactly as typed.
    case several
  }

  /// Chooses the lobby a typed code means among the codes the database
  /// returned. Codes that differ from the typed one in more than case are
  /// ignored (the database treats `*` in the pattern as "anything"). A code
  /// spelled exactly as typed wins over ones that differ in case, so two old
  /// lobbies "beer" and "Beer" can both still be joined.
  static func match(typed: String, among codes: [String]) -> Match {
    let exact = codes.indices.filter { codes[$0] == typed }
    if exact.count == 1 {
      return .one(exact[0])
    }
    if exact.count > 1 {
      return .several
    }
    let sameApartFromCase = codes.indices.filter { isSameCode(codes[$0], typed) }
    switch sameApartFromCase.count {
    case 0:
      return .none
    case 1:
      return .one(sameApartFromCase[0])
    default:
      return .several
    }
  }
}
