import Foundation
import Supabase

struct LobbyViewBackendCoordinator {
  private let backendService = LobbyBackendService()

  func currentSessionAuthContext() async throws -> (userID: UUID, accessToken: String) {
    let session = try await supabase.auth.session
    return (session.user.id, session.accessToken)
  }

  func loadLobbyAnalytics(lobbyID: UUID) async throws -> (LobbyMeta, LobbyAnalyticsPayload) {
    async let meta = backendService.fetchLobbyMetaAndApplyExpiry(lobbyID: lobbyID)
    async let payload = backendService.fetchLobbyAnalytics(lobbyID: lobbyID)
    return try await (meta, payload)
  }

  func refreshLobbyMeta(lobbyID: UUID) async throws -> LobbyMeta {
    try await backendService.fetchLobbyMetaAndApplyExpiry(lobbyID: lobbyID)
  }

  func fetchLobbyMemberIDs(lobbyID: UUID) async throws -> [UUID] {
    try await backendService.fetchLobbyMemberIDs(lobbyID: lobbyID)
  }

  func fetchLobbyRoster(lobbyID: UUID) async throws -> LobbyRoster {
    try await backendService.fetchLobbyRoster(lobbyID: lobbyID)
  }

  func fetchNewDrinks(lobbyID: UUID, after timestamp: Date) async throws -> [LobbyDrink] {
    try await backendService.fetchNewDrinks(lobbyID: lobbyID, after: timestamp)
  }

  func insertDrink(
    lobbyID: UUID,
    name: String,
    volumeMl: Double,
    abv: Double
  ) async throws -> LobbyDrink {
    try await backendService.insertDrink(
      lobbyID: lobbyID,
      name: name,
      volumeMl: volumeMl,
      abv: abv
    )
  }

  func updateDrink(
    lobbyID: UUID,
    drinkID: UUID,
    name: String,
    volumeMl: Double,
    abv: Double
  ) async throws -> LobbyDrink {
    try await backendService.updateDrink(
      lobbyID: lobbyID,
      drinkID: drinkID,
      name: name,
      volumeMl: volumeMl,
      abv: abv
    )
  }

  func deleteDrink(lobbyID: UUID, drinkID: UUID) async throws {
    try await backendService.deleteDrink(lobbyID: lobbyID, drinkID: drinkID)
  }

  func sendMadeItHome(lobbyID: UUID, nickname: String) async throws {
    try await backendService.sendMadeItHome(lobbyID: lobbyID, nickname: nickname)
  }

  func createMotion(
    lobbyID: UUID,
    targetText: String,
    delayMinutes: Int,
    proposerNickname: String
  ) async throws -> LobbyMotion {
    try await backendService.createMotion(
      lobbyID: lobbyID,
      targetText: targetText,
      delayMinutes: delayMinutes,
      proposerNickname: proposerNickname
    )
  }

  func fetchMotions(lobbyID: UUID) async throws -> [LobbyMotion] {
    try await backendService.fetchMotions(lobbyID: lobbyID)
  }

  func castMotionVote(lobbyID: UUID, motionID: UUID, vote: MotionVoteChoice) async throws {
    try await backendService.castMotionVote(lobbyID: lobbyID, motionID: motionID, vote: vote)
  }

  func closeMotion(motionID: UUID, passed: Bool) async throws {
    try await backendService.closeMotion(motionID: motionID, passed: passed)
  }

  func notifyMotionArrivalIfNeeded(lobbyID: UUID, motionID: UUID, targetText: String) async throws -> Bool {
    try await backendService.notifyMotionArrivalIfNeeded(
      lobbyID: lobbyID,
      motionID: motionID,
      targetText: targetText
    )
  }

  func upsertMemberBAC(lobbyID: UUID, userID: UUID, bac: Double, timestamp: Date) async throws {
    try await backendService.upsertMemberBAC(
      lobbyID: lobbyID,
      userID: userID,
      bac: bac,
      timestamp: timestamp
    )
  }

  func revealInviteCode(lobbyID: UUID) async throws -> String {
    try await backendService.fetchInviteCode(lobbyID: lobbyID)
  }

  func closeLobby(lobbyID: UUID, closingBy nickname: String?) async throws {
    try await backendService.closeLobby(lobbyID: lobbyID, closingBy: nickname)
  }

  func leaveLobby(lobbyID: UUID) async throws {
    try await backendService.leaveLobby(lobbyID: lobbyID)
  }

  func deleteLobby(lobbyID: UUID) async throws {
    try await backendService.deleteLobby(lobbyID: lobbyID)
  }

  func fetchLocationSharingSettings(userID: UUID) async -> LocationSharingSettings {
    await backendService.fetchLocationSharingSettings(userID: userID)
  }

  func saveLocationSharingPreference(
    userID: UUID,
    shareForeground: Bool,
    shareBackground: Bool
  ) async throws {
    let update = UserProfileLocationPrefsUpdate(
      shareLocationForeground: shareForeground,
      shareLocationBackground: shareBackground
    )

    try await supabase
      .from("profiles")
      .update(update)
      .eq("id", value: userID)
      .execute()
  }

  func upsertMemberLocation(
    lobbyID: UUID,
    userID: UUID,
    lat: Double,
    lng: Double,
    timestamp: Date
  ) async throws {
    try await backendService.upsertMemberLocation(
      lobbyID: lobbyID,
      userID: userID,
      lat: lat,
      lng: lng,
      timestamp: timestamp
    )
  }

  func clearMemberLocation(lobbyID: UUID, userID: UUID) async throws {
    try await backendService.clearMemberLocation(lobbyID: lobbyID, userID: userID)
  }

  func fetchMemberLocations(lobbyID: UUID) async throws -> [MemberLocationData] {
    try await backendService.fetchMemberLocations(lobbyID: lobbyID)
  }
}

private struct UserProfileLocationPrefsUpdate: Encodable {
  let shareLocationForeground: Bool
  let shareLocationBackground: Bool

  enum CodingKeys: String, CodingKey {
    case shareLocationForeground = "share_location_foreground"
    case shareLocationBackground = "share_location_background"
  }
}
