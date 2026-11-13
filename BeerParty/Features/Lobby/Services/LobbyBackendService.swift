//
//  LobbyBackendService.swift
//  BeerParty
//
//  Created by Codex on 2/14/26.
//
import Foundation
import Supabase

enum LobbyJoinError: LocalizedError {
  case noActiveLobbyForInviteCode
  case duplicateInviteCodes
  case inviteCodeUnavailable

  var errorDescription: String? {
    switch self {
    case .noActiveLobbyForInviteCode:
      return "No active lobby found for that invite code."
    case .duplicateInviteCodes:
      return "Multiple lobbies share that invite code. Ask the host to create a new unique code."
    case .inviteCodeUnavailable:
      return "Invite code is unavailable for this lobby."
    }
  }
}

enum LobbyLifecycleError: LocalizedError {
  case lobbyNotFound
  case notCreator
  case lobbyClosed
  case closeDenied

  var errorDescription: String? {
    switch self {
    case .lobbyNotFound:
      return "Lobby not found."
    case .notCreator:
      return "Only the lobby creator can perform this action."
    case .lobbyClosed:
      return "Lobby is closed. Drinks can no longer be added."
    case .closeDenied:
      return "Could not close lobby due to backend permissions."
    }
  }
}

enum DrinkMutationError: LocalizedError {
  case editWindowExpired
  case invalidInput

  var errorDescription: String? {
    switch self {
    case .editWindowExpired:
      return "Drinks can only be edited or deleted within 15 minutes of being added."
    case .invalidInput:
      return "Enter a drink name, volume, and ABV before saving."
    }
  }
}

struct LobbyAnalyticsPayload {
  let currentUserID: UUID
  let members: [LobbyMemberData]
  let drinks: [LobbyDrink]
  let bacParamsByUserId: [UUID: LobbyBACParamsData]
}

struct LobbyRoster {
  let members: [LobbyMemberData]
  let bacParamsByUserId: [UUID: LobbyBACParamsData]

  // True when the member list on screen no longer matches the lobby.
  static func needsReload(shownMemberIDs: [UUID], latestMemberIDs: [UUID]) -> Bool {
    Set(shownMemberIDs) != Set(latestMemberIDs)
  }
}

struct LobbyMemberData: Identifiable {
  let userId: UUID
  let nickname: String
  let profilePicPath: String?

  var id: UUID { userId }
}

struct MemberLocationData: Identifiable {
  let userId: UUID
  let nickname: String
  let lat: Double
  let lng: Double
  let updatedAt: Date
  let profilePicPath: String?

  var id: UUID { userId }
}

struct LocationSharingSettings {
  let shareForeground: Bool
  let shareBackground: Bool
}

struct LobbyDrink: Identifiable {
  let id: UUID
  let userId: UUID
  let name: String
  let volumeMl: Double
  let abv: Double
  let consumedAt: Date

  var alcoholGrams: Double {
    volumeMl * (abv / 100) * 0.789
  }
}

struct LobbyBACParamsData {
  let userId: UUID
  let tbw: Double
  let eliminationPerHourPromille: Double
}

struct LobbyMeta {
  let lobbyID: UUID
  let createdBy: UUID?
  let createdAt: Date?
  let isActive: Bool
}

struct LobbyMotionVote: Identifiable {
  let motionId: UUID
  let userId: UUID
  let vote: MotionVoteChoice
  let votedAt: Date

  var id: UUID { userId }
}

struct LobbyMotion: Identifiable {
  let id: UUID
  let lobbyId: UUID
  let createdBy: UUID
  let proposerNickname: String
  let targetText: String
  let delayMinutes: Int
  let createdAt: Date
  let targetAt: Date
  let votingClosesAt: Date
  let status: MotionStatus
  let passed: Bool?
  let resolvedAt: Date?
  let notifiedAt: Date?
  let votes: [LobbyMotionVote]

  var ayeCount: Int {
    votes.filter { $0.vote == .aye }.count
  }

  var neighCount: Int {
    votes.filter { $0.vote == .neigh }.count
  }

  var isActive: Bool {
    status == .active
  }
}

struct LobbyBackendService {
  static let madeItHomeDrinkPrefix = "__home__:"
  static let lobbyClosedDrinkPrefix = "__closed__:"
  static let motionArrivedDrinkPrefix = "__motion_due__:"

  // Loads the invite code for a specific lobby.
  func fetchInviteCode(lobbyID: UUID) async throws -> String {
    let rows: [LobbyInviteCodeRow] = try await supabase
      .from("lobbies")
      .select("invite_code")
      .eq("id", value: lobbyID)
      .limit(1)
      .execute()
      .value

    guard let inviteCode = rows.first?.inviteCode, !inviteCode.isEmpty else {
      throw LobbyJoinError.inviteCodeUnavailable
    }
    return inviteCode
  }

  // Joins the current user to the lobby identified by invite code and initializes member rows.
  func joinLobby(inviteCode: String, nickname: String) async throws -> LobbyDestination {
    let session = try await supabase.auth.session
    let lobbyRows: [CreatedLobby] = try await supabase
      .from("lobbies")
      .select("id,name")
      .eq("invite_code", value: inviteCode)
      .eq("is_active", value: true)
      .limit(2)
      .execute()
      .value

    guard !lobbyRows.isEmpty else {
      throw LobbyJoinError.noActiveLobbyForInviteCode
    }
    guard lobbyRows.count == 1, let lobby = lobbyRows.first else {
      throw LobbyJoinError.duplicateInviteCodes
    }

    let memberRequest = CreateLobbyMemberRequest(
      lobbyId: lobby.id,
      userId: session.user.id,
      nickname: nickname,
      role: "guest"
    )

    try await supabase
      .from("lobby_members")
      .upsert(memberRequest, onConflict: "lobby_id,user_id")
      .execute()

    let memberStateRequest = UpsertMemberStateRequest(
      lobbyId: lobby.id,
      userId: session.user.id,
      bacEtimate: nil,
      lat: nil,
      lng: nil,
      updatedAt: Date()
    )

    try await supabase
      .from("member_state")
      .upsert(memberStateRequest, onConflict: "lobby_id,user_id")
      .execute()

    try await ensureCurrentUserBACParams(lobbyID: lobby.id, userID: session.user.id)

    return LobbyDestination(lobbyID: lobby.id, lobbyName: lobby.name)
  }

  // Loads lobby metadata and auto-closes it if it has been active for over 24 hours.
  func fetchLobbyMetaAndApplyExpiry(lobbyID: UUID) async throws -> LobbyMeta {
    let rows: [LobbyMetaRow] = try await supabase
      .from("lobbies")
      .select("id,created_by,created_at,is_active")
      .eq("id", value: lobbyID)
      .limit(1)
      .execute()
      .value

    guard var row = rows.first else {
      throw LobbyLifecycleError.lobbyNotFound
    }

    if row.isActive,
       let createdAt = row.createdAt.flatMap(parsePostgresTimestamp),
       Date().timeIntervalSince(createdAt) >= 24 * 3600
    {
      let update = LobbyActiveUpdateRequest(isActive: false)
      try? await supabase
        .from("lobbies")
        .update(update)
        .eq("id", value: lobbyID)
        .execute()
      row.isActive = false
    }

    return LobbyMeta(
      lobbyID: row.id,
      createdBy: row.createdBy,
      createdAt: row.createdAt.flatMap(parsePostgresTimestamp),
      isActive: row.isActive
    )
  }

  // Closes the lobby by setting is_active=false. Only the creator can do this.
  func closeLobby(lobbyID: UUID, closingBy nickname: String?) async throws {
    let session = try await supabase.auth.session
    let ownerRows: [LobbyMetaRow] = try await supabase
      .from("lobbies")
      .select("id,created_by,created_at,is_active")
      .eq("id", value: lobbyID)
      .eq("created_by", value: session.user.id)
      .limit(1)
      .execute()
      .value

    guard !ownerRows.isEmpty else {
      throw LobbyLifecycleError.notCreator
    }

    let update = LobbyActiveUpdateRequest(isActive: false)
    let updatedRows: [LobbyMetaRow] = try await supabase
      .from("lobbies")
      .update(update, returning: .representation)
      .eq("id", value: lobbyID)
      .eq("created_by", value: session.user.id)
      .execute()
      .value

    guard !updatedRows.isEmpty else {
      throw LobbyLifecycleError.closeDenied
    }

    // Best-effort marker used for in-lobby "closed" event propagation; must not block closure.
    let timestamp = Date()
    let closer = (nickname ?? "Host").trimmingCharacters(in: .whitespacesAndNewlines)
    let payloadName = "\(Self.lobbyClosedDrinkPrefix)\(Self.iso8601WithFractionalSeconds.string(from: timestamp))|\(closer.isEmpty ? "Host" : closer)"
    let marker = CreateDrinkRequest(
      lobbyId: lobbyID,
      userId: session.user.id,
      name: payloadName,
      volumeMl: 0,
      abv: 0,
      consumedAt: timestamp
    )
    try? await supabase
      .from("drinks")
      .insert(marker)
      .execute()
  }

  // Removes the current user from this lobby and deletes their lobby-specific data.
  func leaveLobby(lobbyID: UUID) async throws {
    let session = try await supabase.auth.session
    let userID = session.user.id

    try await supabase
      .from("drinks")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: userID)
      .execute()

    try await supabase
      .from("member_state")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: userID)
      .execute()

    try await supabase
      .from("lobby_member_bac_params")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: userID)
      .execute()

    try await supabase
      .from("lobby_members")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: userID)
      .execute()
  }

  // Deletes the full lobby and all related data. Only the creator can do this.
  func deleteLobby(lobbyID: UUID) async throws {
    let session = try await supabase.auth.session
    let ownerRows: [LobbyMetaRow] = try await supabase
      .from("lobbies")
      .select("id,created_by,created_at,is_active")
      .eq("id", value: lobbyID)
      .eq("created_by", value: session.user.id)
      .limit(1)
      .execute()
      .value

    guard !ownerRows.isEmpty else {
      throw LobbyLifecycleError.notCreator
    }

    try await supabase
      .from("drinks")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .execute()

    try await supabase
      .from("member_state")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .execute()

    try await supabase
      .from("lobby_member_bac_params")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .execute()

    try await supabase
      .from("lobby_members")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .execute()

    try await supabase
      .from("lobbies")
      .delete()
      .eq("id", value: lobbyID)
      .eq("created_by", value: session.user.id)
      .execute()
  }

  // Ensures the signed-in user has a BAC-parameter row for this lobby.
  func ensureBACParamsForCurrentUser(lobbyID: UUID) async throws {
    let session = try await supabase.auth.session
    try await ensureCurrentUserBACParams(lobbyID: lobbyID, userID: session.user.id)
  }

  // Creates a new drink row for the current user in the target lobby.
  func insertDrink(
    lobbyID: UUID,
    name: String,
    volumeMl: Double,
    abv: Double
  ) async throws -> LobbyDrink {
    let meta = try await fetchLobbyMetaAndApplyExpiry(lobbyID: lobbyID)
    guard meta.isActive else {
      throw LobbyLifecycleError.lobbyClosed
    }

    let session = try await supabase.auth.session
    let request = CreateDrinkRequest(
      lobbyId: lobbyID,
      userId: session.user.id,
      name: name,
      volumeMl: volumeMl,
      abv: abv,
      consumedAt: Date()
    )

    let insertedRows: [DrinkRow] = try await supabase
      .from("drinks")
      .insert(request)
      .select("id,user_id,name,volume_ml,abv,consumed_at")
      .execute()
      .value

    return insertedRows.first.flatMap(drink(from:)) ?? LobbyDrink(
      id: UUID(),
      userId: session.user.id,
      name: name,
      volumeMl: volumeMl,
      abv: abv,
      consumedAt: request.consumedAt
    )
  }

  func updateDrink(
    lobbyID: UUID,
    drinkID: UUID,
    name: String,
    volumeMl: Double,
    abv: Double
  ) async throws -> LobbyDrink {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty, volumeMl > 0, abv >= 0 else {
      throw DrinkMutationError.invalidInput
    }

    let meta = try await fetchLobbyMetaAndApplyExpiry(lobbyID: lobbyID)
    guard meta.isActive else {
      throw LobbyLifecycleError.lobbyClosed
    }

    let session = try await supabase.auth.session
    let cutoff = Date().addingTimeInterval(-15 * 60)
    let request = UpdateDrinkRequest(
      name: trimmedName,
      volumeMl: volumeMl,
      abv: abv
    )

    let updatedRows: [DrinkRow] = try await supabase
      .from("drinks")
      .update(request)
      .eq("id", value: drinkID)
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: session.user.id)
      .gte("consumed_at", value: Self.iso8601WithFractionalSeconds.string(from: cutoff))
      .select("id,user_id,name,volume_ml,abv,consumed_at")
      .execute()
      .value

    guard let updatedDrink = updatedRows.first.flatMap(drink(from:)) else {
      throw DrinkMutationError.editWindowExpired
    }

    return updatedDrink
  }

  func deleteDrink(lobbyID: UUID, drinkID: UUID) async throws {
    let meta = try await fetchLobbyMetaAndApplyExpiry(lobbyID: lobbyID)
    guard meta.isActive else {
      throw LobbyLifecycleError.lobbyClosed
    }

    let session = try await supabase.auth.session
    let cutoff = Date().addingTimeInterval(-15 * 60)
    let deletedRows: [DrinkRow] = try await supabase
      .from("drinks")
      .delete()
      .eq("id", value: drinkID)
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: session.user.id)
      .gte("consumed_at", value: Self.iso8601WithFractionalSeconds.string(from: cutoff))
      .select("id,user_id,name,volume_ml,abv,consumed_at")
      .execute()
      .value

    guard !deletedRows.isEmpty else {
      throw DrinkMutationError.editWindowExpired
    }
  }

  // Writes a "made it home" event as a zero-alcohol marker that all lobby members can receive.
  func sendMadeItHome(lobbyID: UUID, nickname: String) async throws {
    let meta = try await fetchLobbyMetaAndApplyExpiry(lobbyID: lobbyID)
    guard meta.isActive else {
      throw LobbyLifecycleError.lobbyClosed
    }

    let session = try await supabase.auth.session
    let safeNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    let payloadNickname = safeNickname.isEmpty ? "Member" : safeNickname
    let request = CreateDrinkRequest(
      lobbyId: lobbyID,
      userId: session.user.id,
      name: "\(Self.madeItHomeDrinkPrefix)\(payloadNickname)",
      volumeMl: 0,
      abv: 0,
      consumedAt: Date()
    )

    try await supabase
      .from("drinks")
      .insert(request)
      .execute()
  }

  func createMotion(
    lobbyID: UUID,
    targetText: String,
    delayMinutes: Int,
    proposerNickname: String
  ) async throws -> LobbyMotion {
    let meta = try await fetchLobbyMetaAndApplyExpiry(lobbyID: lobbyID)
    guard meta.isActive else {
      throw LobbyLifecycleError.lobbyClosed
    }

    let session = try await supabase.auth.session
    let now = Date()
    let cleanTarget = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanNickname = proposerNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    let request = CreateMotionRequest(
      lobbyId: lobbyID,
      createdBy: session.user.id,
      proposerNickname: cleanNickname.isEmpty ? "Member" : cleanNickname,
      targetText: cleanTarget,
      delayMinutes: delayMinutes,
      targetAt: now.addingTimeInterval(TimeInterval(delayMinutes * 60)),
      votingClosesAt: now.addingTimeInterval(10 * 60)
    )

    let rows: [LobbyMotionRow] = try await supabase
      .from("motions")
      .insert(request)
      .select("id,lobby_id,created_by,proposer_nickname,target_text,delay_minutes,created_at,target_at,voting_closes_at,status,passed,resolved_at,notified_at")
      .limit(1)
      .execute()
      .value

    guard let row = rows.first,
          let motion = motionFromRow(row, votesByMotionID: [:]) else {
      throw LobbyLifecycleError.lobbyNotFound
    }
    return motion
  }

  func fetchMotions(lobbyID: UUID) async throws -> [LobbyMotion] {
    let motionRows: [LobbyMotionRow] = try await supabase
      .from("motions")
      .select("id,lobby_id,created_by,proposer_nickname,target_text,delay_minutes,created_at,target_at,voting_closes_at,status,passed,resolved_at,notified_at")
      .eq("lobby_id", value: lobbyID)
      .order("created_at", ascending: false)
      .execute()
      .value

    let voteRows: [LobbyMotionVoteRow] = try await supabase
      .from("motion_votes")
      .select("motion_id,user_id,vote,voted_at")
      .eq("lobby_id", value: lobbyID)
      .execute()
      .value

    let votesByMotionID = Dictionary(grouping: voteRows) { $0.motionId }
    return motionRows.compactMap { motionFromRow($0, votesByMotionID: votesByMotionID) }
  }

  func castMotionVote(
    lobbyID: UUID,
    motionID: UUID,
    vote: MotionVoteChoice
  ) async throws {
    let session = try await supabase.auth.session
    let request = CreateMotionVoteRequest(
      motionId: motionID,
      lobbyId: lobbyID,
      userId: session.user.id,
      vote: vote,
      votedAt: Date()
    )

    try await supabase
      .from("motion_votes")
      .upsert(request, onConflict: "motion_id,user_id")
      .execute()
  }

  func closeMotion(
    motionID: UUID,
    passed: Bool
  ) async throws {
    let request = MotionResolveUpdateRequest(
      status: .closed,
      passed: passed,
      resolvedAt: Date()
    )

    try await supabase
      .from("motions")
      .update(request)
      .eq("id", value: motionID)
      .eq("status", value: MotionStatus.active.rawValue)
      .execute()
  }

  // Marks the motion as notified once and writes a broadcast marker for lobby members.
  func notifyMotionArrivalIfNeeded(lobbyID: UUID, motionID: UUID, targetText: String) async throws -> Bool {
    let session = try await supabase.auth.session
    let existingRows: [LobbyMotionRow] = try await supabase
      .from("motions")
      .select("id,lobby_id,created_by,proposer_nickname,target_text,delay_minutes,created_at,target_at,voting_closes_at,status,passed,resolved_at,notified_at")
      .eq("id", value: motionID)
      .eq("lobby_id", value: lobbyID)
      .limit(1)
      .execute()
      .value
    guard let existing = existingRows.first,
          existing.passed == true,
          existing.notifiedAt == nil else {
      return false
    }

    let notifyRequest = MotionNotifiedUpdateRequest(notifiedAt: Date())

    let updatedRows: [MotionNotificationRow] = try await supabase
      .from("motions")
      .update(notifyRequest, returning: .representation)
      .eq("id", value: motionID)
      .eq("lobby_id", value: lobbyID)
      .eq("passed", value: true)
      .select("id")
      .execute()
      .value

    guard !updatedRows.isEmpty else { return false }

    let compactTarget = targetText
      .replacingOccurrences(of: "|", with: "/")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let payload = compactTarget.isEmpty ? "the destination" : compactTarget
    let marker = CreateDrinkRequest(
      lobbyId: lobbyID,
      userId: session.user.id,
      name: "\(Self.motionArrivedDrinkPrefix)\(motionID.uuidString)|\(payload)",
      volumeMl: 0,
      abv: 0,
      consumedAt: Date()
    )
    try? await supabase
      .from("drinks")
      .insert(marker)
      .execute()

    return true
  }

  // Fetches members, drinks, and BAC parameters needed by the lobby BAC UI.
  func fetchLobbyAnalytics(lobbyID: UUID) async throws -> LobbyAnalyticsPayload {
    let session = try await supabase.auth.session
    try? await ensureCurrentUserBACParams(lobbyID: lobbyID, userID: session.user.id)

    let roster = try await fetchLobbyRoster(lobbyID: lobbyID)

    let drinkRows: [DrinkRow] = try await supabase
      .from("drinks")
      .select("id,user_id,name,volume_ml,abv,consumed_at")
      .eq("lobby_id", value: lobbyID)
      .order("consumed_at", ascending: true)
      .execute()
      .value

    let drinks = drinkRows.compactMap { row -> LobbyDrink? in
      drink(from: row)
    }

    return LobbyAnalyticsPayload(
      currentUserID: session.user.id,
      members: roster.members,
      drinks: drinks,
      bacParamsByUserId: roster.bacParamsByUserId
    )
  }

  // Loads the lobby's members and their BAC parameters, without drinks.
  func fetchLobbyRoster(lobbyID: UUID) async throws -> LobbyRoster {
    let memberRows: [LobbyMemberRow] = try await supabase
      .from("lobby_members")
      .select("user_id,nickname")
      .eq("lobby_id", value: lobbyID)
      .execute()
      .value

    let memberIDs = memberRows.map(\.userId)

    var profilePicByUserID: [UUID: String] = [:]
    for memberID in memberIDs {
      if let profileRow: ProfilePhotoRow = try? await supabase
        .from("profiles")
        .select("id,profile_pic_path")
        .eq("id", value: memberID)
        .single()
        .execute()
        .value
      {
        profilePicByUserID[memberID] = profileRow.profilePicPath
      }
    }

    let members = memberRows.map {
      let cleanedNickname = ($0.nickname ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return LobbyMemberData(
        userId: $0.userId,
        nickname: cleanedNickname.isEmpty ? "Member" : cleanedNickname,
        profilePicPath: profilePicByUserID[$0.userId]
      )
    }

    var bacParamsByUserId: [UUID: LobbyBACParamsData] = [:]
    do {
      let bacParamsRows: [LobbyBACParamsRow] = try await supabase
        .from("lobby_member_bac_params")
        .select("user_id,tbw,elim_rate")
        .eq("lobby_id", value: lobbyID)
        .execute()
        .value

      for row in bacParamsRows {
        guard let tbw = row.tbw, let elimRate = row.elimRate else { continue }
        bacParamsByUserId[row.userId] = LobbyBACParamsData(
          userId: row.userId,
          tbw: tbw,
          eliminationPerHourPromille: elimRate
        )
      }
    } catch {
      // Allow tracker to continue with fallback parameters if this table/policy is not ready yet.
    }

    return LobbyRoster(members: members, bacParamsByUserId: bacParamsByUserId)
  }

  // One cheap request for the live refresh to notice members joining or leaving.
  func fetchLobbyMemberIDs(lobbyID: UUID) async throws -> [UUID] {
    let memberRows: [LobbyMemberRow] = try await supabase
      .from("lobby_members")
      .select("user_id,nickname")
      .eq("lobby_id", value: lobbyID)
      .execute()
      .value

    return memberRows.map(\.userId)
  }

  func fetchLocationSharingSettings(userID: UUID) async -> LocationSharingSettings {
    do {
      let profile: UserProfile = try await supabase
        .from("profiles")
        .select("id,weight,age,gender,profile_pic_path,share_location_foreground,share_location_background")
        .eq("id", value: userID)
        .single()
        .execute()
        .value
      return LocationSharingSettings(
        shareForeground: profile.shareLocationForeground,
        shareBackground: profile.shareLocationBackground
      )
    } catch {
      return LocationSharingSettings(shareForeground: false, shareBackground: false)
    }
  }

  func upsertMemberLocation(
    lobbyID: UUID,
    userID: UUID,
    lat: Double,
    lng: Double,
    timestamp: Date
  ) async throws {
    let request = UpdateMemberLocationRequest(
      lobbyId: lobbyID,
      userId: userID,
      lat: lat,
      lng: lng,
      updatedAt: timestamp
    )

    try await supabase
      .from("member_state")
      .upsert(request, onConflict: "lobby_id,user_id")
      .execute()
  }

  func clearMemberLocation(
    lobbyID: UUID,
    userID: UUID,
    timestamp: Date = Date()
  ) async throws {
    let request = UpdateMemberLocationRequest(
      lobbyId: lobbyID,
      userId: userID,
      lat: nil,
      lng: nil,
      updatedAt: timestamp
    )

    try await supabase
      .from("member_state")
      .upsert(request, onConflict: "lobby_id,user_id")
      .execute()
  }

  func fetchMemberLocations(lobbyID: UUID) async throws -> [MemberLocationData] {
    let memberRows: [LobbyMemberRow] = try await supabase
      .from("lobby_members")
      .select("user_id,nickname")
      .eq("lobby_id", value: lobbyID)
      .execute()
      .value

    let stateRows: [MemberStateLocationRow] = try await supabase
      .from("member_state")
      .select("user_id,lat,lng,updated_at")
      .eq("lobby_id", value: lobbyID)
      .execute()
      .value

    var profilePicByUserID: [UUID: String] = [:]
    for member in memberRows {
      if let profileRow: ProfilePhotoRow = try? await supabase
        .from("profiles")
        .select("id,profile_pic_path")
        .eq("id", value: member.userId)
        .single()
        .execute()
        .value
      {
        profilePicByUserID[member.userId] = profileRow.profilePicPath
      }
    }

    let nicknameByUserID = Dictionary(
      uniqueKeysWithValues: memberRows.map { row in
        let cleanedNickname = (row.nickname ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return (row.userId, cleanedNickname.isEmpty ? "Member" : cleanedNickname)
      }
    )

    return stateRows.compactMap { row in
      guard let lat = row.lat, let lng = row.lng else { return nil }
      guard let updatedAt = parsePostgresTimestamp(row.updatedAt) else { return nil }
      let nickname = nicknameByUserID[row.userId] ?? "Member"
      return MemberLocationData(
        userId: row.userId,
        nickname: nickname,
        lat: lat,
        lng: lng,
        updatedAt: updatedAt,
        profilePicPath: profilePicByUserID[row.userId]
      )
    }
  }

  // Fetches only drinks newer than the provided timestamp for cheap live updates.
  func fetchNewDrinks(
    lobbyID: UUID,
    after timestamp: Date
  ) async throws -> [LobbyDrink] {
    let rows: [DrinkRow] = try await supabase
      .from("drinks")
      .select("id,user_id,name,volume_ml,abv,consumed_at")
      .eq("lobby_id", value: lobbyID)
      .gt("consumed_at", value: Self.iso8601WithFractionalSeconds.string(from: timestamp))
      .order("consumed_at", ascending: true)
      .execute()
      .value

    return rows.compactMap { row in
      drink(from: row)
    }
  }

  // Writes the user's latest BAC estimate into member_state.
  func upsertMemberBAC(
    lobbyID: UUID,
    userID: UUID,
    bac: Double,
    timestamp: Date
  ) async throws {
    let request = UpsertMemberBACRequest(
      lobbyId: lobbyID,
      userId: userID,
      bacEstimate: bac,
      updatedAt: timestamp
    )

    do {
      try await supabase
        .from("member_state")
        .upsert(request, onConflict: "lobby_id,user_id")
        .execute()
    } catch {
      let legacyRequest = UpsertMemberBACLegacyRequest(
        lobbyId: lobbyID,
        userId: userID,
        bacEtimate: bac,
        updatedAt: timestamp
      )
      try await supabase
        .from("member_state")
        .upsert(legacyRequest, onConflict: "lobby_id,user_id")
        .execute()
    }
  }

  // Parses timestamptz strings from Postgres into Date values.
  private func parsePostgresTimestamp(_ raw: String) -> Date? {
    if let withFractions = Self.iso8601WithFractionalSeconds.date(from: raw) {
      return withFractions
    }
    return Self.iso8601.date(from: raw)
  }

  private func motionFromRow(
    _ row: LobbyMotionRow,
    votesByMotionID: [UUID: [LobbyMotionVoteRow]]
  ) -> LobbyMotion? {
    guard let createdAt = parsePostgresTimestamp(row.createdAt),
          let targetAt = parsePostgresTimestamp(row.targetAt),
          let votingClosesAt = parsePostgresTimestamp(row.votingClosesAt) else {
      return nil
    }

    let voteRows = votesByMotionID[row.id] ?? []
    let votes: [LobbyMotionVote] = voteRows.compactMap { voteRow in
      guard let votedAt = parsePostgresTimestamp(voteRow.votedAt),
            let vote = MotionVoteChoice(rawValue: voteRow.vote.lowercased()) else {
        return nil
      }
      return LobbyMotionVote(
        motionId: voteRow.motionId,
        userId: voteRow.userId,
        vote: vote,
        votedAt: votedAt
      )
    }

    return LobbyMotion(
      id: row.id,
      lobbyId: row.lobbyId,
      createdBy: row.createdBy,
      proposerNickname: row.proposerNickname,
      targetText: row.targetText,
      delayMinutes: row.delayMinutes,
      createdAt: createdAt,
      targetAt: targetAt,
      votingClosesAt: votingClosesAt,
      status: MotionStatus(rawValue: row.status.lowercased()) ?? .active,
      passed: row.passed,
      resolvedAt: row.resolvedAt.flatMap(parsePostgresTimestamp),
      notifiedAt: row.notifiedAt.flatMap(parsePostgresTimestamp),
      votes: votes.sorted { $0.votedAt < $1.votedAt }
    )
  }

  // Ensures the current user has derived BAC parameters saved for this lobby.
  private func ensureCurrentUserBACParams(lobbyID: UUID, userID: UUID) async throws {
    let existing: [LobbyBACParamsRow] = try await supabase
      .from("lobby_member_bac_params")
      .select("user_id,tbw,elim_rate")
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: userID)
      .limit(1)
      .execute()
      .value

    if !existing.isEmpty {
      return
    }

    let derived: LobbyBACParamsData
    do {
      let profile: UserProfile = try await supabase
        .from("profiles")
        .select("id,weight,age,gender")
        .eq("id", value: userID)
        .single()
        .execute()
        .value
      derived = deriveBACParametersFromProfile(profile)
    } catch {
      derived = LobbyBACParamsData(
        userId: userID,
        tbw: 40,
        eliminationPerHourPromille: 0.14
      )
    }
    let request = UpsertLobbyBACParamsRequest(
      lobbyId: lobbyID,
      userId: userID,
      tbw: derived.tbw,
      elimRate: derived.eliminationPerHourPromille,
      updatedAt: Date()
    )

    try await supabase
      .from("lobby_member_bac_params")
      .upsert(request, onConflict: "lobby_id,user_id")
      .execute()
  }

  // Derives TBW and elimination rate from profile fields once per user/lobby.
  private func deriveBACParametersFromProfile(_ profile: UserProfile) -> LobbyBACParamsData {
    let weightKg = max(40, profile.weight / 2.20462)
    let age = max(18, profile.age)
    let gender = profile.gender.lowercased()

    if gender.contains("female") {
      return LobbyBACParamsData(
        userId: profile.id,
        tbw: max(20, 14.46 + 0.2549 * weightKg),
        eliminationPerHourPromille: 0.15
      )
    }
    if gender.contains("male") {
      return LobbyBACParamsData(
        userId: profile.id,
        tbw: max(20, 20.03 - 0.1183 * Double(age) + 0.3626 * weightKg),
        eliminationPerHourPromille: 0.13
      )
    }
    return LobbyBACParamsData(
      userId: profile.id,
      tbw: max(20, 17.25 + 0.308 * weightKg),
      eliminationPerHourPromille: 0.14
    )
  }

  private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let iso8601: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  private func drink(from row: DrinkRow) -> LobbyDrink? {
    guard let consumedAt = parsePostgresTimestamp(row.consumedAt) else { return nil }
    return LobbyDrink(
      id: row.id,
      userId: row.userId,
      name: row.name,
      volumeMl: row.volumeMl,
      abv: row.abv,
      consumedAt: consumedAt
    )
  }
}

private struct LobbyMemberRow: Decodable {
  let userId: UUID
  let nickname: String?

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case nickname
  }
}

private struct ProfilePhotoRow: Decodable {
  let id: UUID
  let profilePicPath: String?

  enum CodingKeys: String, CodingKey {
    case id
    case profilePicPath = "profile_pic_path"
  }
}

private struct MemberStateLocationRow: Decodable {
  let userId: UUID
  let lat: Double?
  let lng: Double?
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case lat
    case lng
    case updatedAt = "updated_at"
  }
}

private struct DrinkRow: Decodable {
  let id: UUID
  let userId: UUID
  let name: String
  let volumeMl: Double
  let abv: Double
  let consumedAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case name
    case volumeMl = "volume_ml"
    case abv
    case consumedAt = "consumed_at"
  }
}

private struct LobbyBACParamsRow: Decodable {
  let userId: UUID
  let tbw: Double?
  let elimRate: Double?

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case tbw
    case elimRate = "elim_rate"
  }
}

private struct LobbyInviteCodeRow: Decodable {
  let inviteCode: String

  enum CodingKeys: String, CodingKey {
    case inviteCode = "invite_code"
  }
}

private struct LobbyMetaRow: Decodable {
  let id: UUID
  let createdBy: UUID?
  let createdAt: String?
  var isActive: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case createdBy = "created_by"
    case createdAt = "created_at"
    case isActive = "is_active"
  }
}

private struct LobbyMotionRow: Decodable {
  let id: UUID
  let lobbyId: UUID
  let createdBy: UUID
  let proposerNickname: String
  let targetText: String
  let delayMinutes: Int
  let createdAt: String
  let targetAt: String
  let votingClosesAt: String
  let status: String
  let passed: Bool?
  let resolvedAt: String?
  let notifiedAt: String?

  enum CodingKeys: String, CodingKey {
    case id
    case lobbyId = "lobby_id"
    case createdBy = "created_by"
    case proposerNickname = "proposer_nickname"
    case targetText = "target_text"
    case delayMinutes = "delay_minutes"
    case createdAt = "created_at"
    case targetAt = "target_at"
    case votingClosesAt = "voting_closes_at"
    case status
    case passed
    case resolvedAt = "resolved_at"
    case notifiedAt = "notified_at"
  }
}

private struct LobbyMotionVoteRow: Decodable {
  let motionId: UUID
  let userId: UUID
  let vote: String
  let votedAt: String

  enum CodingKeys: String, CodingKey {
    case motionId = "motion_id"
    case userId = "user_id"
    case vote
    case votedAt = "voted_at"
  }
}

private struct MotionNotificationRow: Decodable {
  let id: UUID
}

private struct LobbyActiveUpdateRequest: Encodable {
  let isActive: Bool

  enum CodingKeys: String, CodingKey {
    case isActive = "is_active"
  }
}
