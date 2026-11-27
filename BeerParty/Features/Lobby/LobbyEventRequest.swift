import Foundation

/// The three things that happen in a lobby besides drinks. The raw values are
/// the ones the `lobby_events` table accepts.
enum LobbyEventKind: String, Codable {
  case madeItHome = "made_it_home"
  case lobbyClosed = "lobby_closed"
  case motionDue = "motion_due"
}

/// A new row for `lobby_events` (backlog B5). The row carries no free text and
/// no user or time: the database fills in the signed-in user and its own
/// clock, and the app shows nickname and motion text from their own tables.
///
/// Built only through the three functions below, because the table refuses a
/// motion id on anything but `motion_due`, and a `motion_due` without one.
struct LobbyEventRequest: Encodable, Equatable {
  let lobbyId: UUID
  let kind: LobbyEventKind
  /// Left out of the JSON when nil.
  let motionId: UUID?

  private init(lobbyId: UUID, kind: LobbyEventKind, motionId: UUID?) {
    self.lobbyId = lobbyId
    self.kind = kind
    self.motionId = motionId
  }

  static func madeItHome(lobbyID: UUID) -> LobbyEventRequest {
    LobbyEventRequest(lobbyId: lobbyID, kind: .madeItHome, motionId: nil)
  }

  static func lobbyClosed(lobbyID: UUID) -> LobbyEventRequest {
    LobbyEventRequest(lobbyId: lobbyID, kind: .lobbyClosed, motionId: nil)
  }

  static func motionDue(lobbyID: UUID, motionID: UUID) -> LobbyEventRequest {
    LobbyEventRequest(lobbyId: lobbyID, kind: .motionDue, motionId: motionID)
  }

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case kind
    case motionId = "motion_id"
  }
}
