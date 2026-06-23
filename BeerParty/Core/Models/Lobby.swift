//
//  Lobby.swift
//  BeerParty
//
//  Created by Codex on 2/11/26.
//
import Foundation

struct CreateLobbyRequest: Encodable {
  let createdBy: UUID
  let name: String
  let inviteCode: String
  let isActive: Bool

  enum CodingKeys: String, CodingKey {
    case createdBy = "created_by"
    case name
    case inviteCode = "invite_code"
    case isActive = "is_active"
  }
}

struct CreatedLobby: Decodable {
  let id: UUID
  let name: String
}

struct CreateLobbyMemberRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let nickname: String
  let role: String

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case nickname
    case role
  }
}

struct LobbyDestination: Identifiable, Hashable {
  let lobbyID: UUID
  let lobbyName: String

  var id: UUID { lobbyID }
}

struct LobbyMembershipRow: Decodable {
  let lobbyID: UUID

  enum CodingKeys: String, CodingKey {
    case lobbyID = "lobby_id"
  }
}

struct LobbySummary: Decodable {
  let id: UUID
  let name: String
  let isActive: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case isActive = "is_active"
  }
}

struct UpsertMemberStateRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let bacEtimate: Double?
  let lat: Double?
  let lng: Double?
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case bacEtimate = "bac_etimate"
    case lat
    case lng
    case updatedAt = "updated_at"
  }
}

struct UpdateMemberLocationRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let lat: Double?
  let lng: Double?
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case lat
    case lng
    case updatedAt = "updated_at"
  }
}

struct UpsertMemberBACRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let bacEstimate: Double
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case bacEstimate = "bac_estimate"
    case updatedAt = "updated_at"
  }
}

struct UpsertMemberBACLegacyRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let bacEtimate: Double
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case bacEtimate = "bac_etimate"
    case updatedAt = "updated_at"
  }
}

struct CreateDrinkRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let name: String
  let volumeMl: Double
  let abv: Double
  let consumedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case name
    case volumeMl = "volume_ml"
    case abv
    case consumedAt = "consumed_at"
  }
}

struct UpdateDrinkRequest: Encodable {
  let name: String
  let volumeMl: Double
  let abv: Double

  enum CodingKeys: String, CodingKey {
    case name
    case volumeMl = "volume_ml"
    case abv
  }
}

struct UpsertLobbyBACParamsRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let tbw: Double
  let elimRate: Double
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case tbw
    case elimRate = "elim_rate"
    case updatedAt = "updated_at"
  }
}

enum MotionVoteChoice: String, Codable, CaseIterable {
  case aye
  case neigh
}

enum MotionStatus: String, Codable {
  case active
  case closed
}

struct CreateMotionRequest: Encodable {
  let lobbyId: UUID
  let createdBy: UUID
  let proposerNickname: String
  let targetText: String
  let delayMinutes: Int
  let targetAt: Date
  let votingClosesAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case createdBy = "created_by"
    case proposerNickname = "proposer_nickname"
    case targetText = "target_text"
    case delayMinutes = "delay_minutes"
    case targetAt = "target_at"
    case votingClosesAt = "voting_closes_at"
  }
}

struct CreateMotionVoteRequest: Encodable {
  let motionId: UUID
  let lobbyId: UUID
  let userId: UUID
  let vote: MotionVoteChoice
  let votedAt: Date

  enum CodingKeys: String, CodingKey {
    case motionId = "motion_id"
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case vote
    case votedAt = "voted_at"
  }
}

struct MotionResolveUpdateRequest: Encodable {
  let status: MotionStatus
  let passed: Bool
  let resolvedAt: Date

  enum CodingKeys: String, CodingKey {
    case status
    case passed
    case resolvedAt = "resolved_at"
  }
}

struct MotionNotifiedUpdateRequest: Encodable {
  let notifiedAt: Date

  enum CodingKeys: String, CodingKey {
    case notifiedAt = "notified_at"
  }
}
