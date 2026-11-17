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
}
