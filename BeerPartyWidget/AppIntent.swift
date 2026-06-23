import Foundation
import AppIntents

struct QuickAddDrinkPreset: Codable, Hashable {
  let id: String
  let name: String
  let volumeMl: Double
  let abv: Double
}

struct LobbyQuickAddContext: Codable {
  let lobbyID: UUID
  let lobbyName: String
  let userID: UUID
  let accessToken: String
  let supabaseURL: String
  let supabaseAnonKey: String
  let lastCustomPreset: QuickAddDrinkPreset?
  let activeMotionID: UUID?
  let activeMotionTargetText: String?
  let shouldShowMotionVote: Bool?
  let updatedAt: Date
}

enum LobbyQuickAddStore {
  static let appGroupID = "group.com.beerparty.shared"
  static let key = "lobby.quickadd.context"
}

@available(iOS 17.0, *)
enum QuickAddChoice: String, AppEnum {
  case beer
  case wine
  case shot
  case water
  case custom

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Drink"

  static var caseDisplayRepresentations: [QuickAddChoice: DisplayRepresentation] = [
    .beer: "Beer",
    .wine: "Wine",
    .shot: "Shot",
    .water: "Water",
    .custom: "Custom"
  ]
}

@available(iOS 17.0, *)
enum MotionVoteIntentChoice: String, AppEnum {
  case aye
  case neigh

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Motion Vote"

  static var caseDisplayRepresentations: [MotionVoteIntentChoice: DisplayRepresentation] = [
    .aye: "Aye",
    .neigh: "Neigh"
  ]
}

@available(iOS 17.0, *)
struct QuickAddDrinkIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Quick Add Drink"
  static var openAppWhenRun = false
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

  @Parameter(title: "Preset")
  var preset: QuickAddChoice

  init() {}

  init(preset: QuickAddChoice) {
    self.preset = preset
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let context = loadContext() else {
      return .result(dialog: "No active lobby found. Verify App Group is enabled on app and widget.")
    }

    guard let selected = selectedPreset(from: context) else {
      return .result(dialog: "Custom drink unavailable.")
    }

    do {
      try await insertDrink(context: context, preset: selected)
      return .result(dialog: "Added \(selected.name).")
    } catch {
      return .result(dialog: "Could not add drink. \(error.localizedDescription)")
    }
  }

  private func loadContext() -> LobbyQuickAddContext? {
    guard let defaults = UserDefaults(suiteName: LobbyQuickAddStore.appGroupID),
          let data = defaults.data(forKey: LobbyQuickAddStore.key)
    else {
      return nil
    }

    return try? JSONDecoder().decode(LobbyQuickAddContext.self, from: data)
  }

  private func selectedPreset(from context: LobbyQuickAddContext) -> QuickAddDrinkPreset? {
    switch preset {
    case .beer:
      return QuickAddDrinkPreset(id: "beer", name: "Beer", volumeMl: 330, abv: 5)
    case .wine:
      return QuickAddDrinkPreset(id: "wine", name: "Wine", volumeMl: 150, abv: 12)
    case .shot:
      return QuickAddDrinkPreset(id: "shot", name: "Shot", volumeMl: 44, abv: 40)
    case .water:
      return QuickAddDrinkPreset(id: "water", name: "Water", volumeMl: 250, abv: 0)
    case .custom:
      return context.lastCustomPreset
    }
  }

  private func insertDrink(context: LobbyQuickAddContext, preset: QuickAddDrinkPreset) async throws {
    guard let url = URL(string: "\(context.supabaseURL)/rest/v1/drinks") else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue(context.supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.addValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
    request.timeoutInterval = 12

    let payload: [String: Any] = [
      "lobby_id": context.lobbyID.uuidString,
      "user_id": context.userID.uuidString,
      "name": preset.name,
      "volume_ml": preset.volumeMl,
      "abv": preset.abv,
      "consumed_at": ISO8601DateFormatter().string(from: Date())
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw QuickAddIntentError(message: "No HTTP response from Supabase.")
    }

    guard (200..<300).contains(http.statusCode) else {
      let serverMessage = String(data: data, encoding: .utf8)?
        .replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown server error"
      throw QuickAddIntentError(message: "Supabase \(http.statusCode): \(serverMessage)")
    }
  }
}

private struct QuickAddIntentError: LocalizedError {
  let message: String

  var errorDescription: String? { message }
}

@available(iOS 17.0, *)
struct CastMotionVoteIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Vote on Motion"
  static var openAppWhenRun = false
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

  @Parameter(title: "Vote")
  var vote: MotionVoteIntentChoice

  init() {}

  init(vote: MotionVoteIntentChoice) {
    self.vote = vote
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let context = loadContext() else {
      return .result(dialog: "No active lobby found.")
    }

    guard (context.shouldShowMotionVote ?? false), let motionID = context.activeMotionID else {
      return .result(dialog: "No active motion to vote on.")
    }

    do {
      try await castVote(context: context, motionID: motionID)
      let label = vote == .aye ? "Aye" : "Neigh"
      return .result(dialog: "\(label) vote submitted.")
    } catch {
      return .result(dialog: "Could not submit vote. \(error.localizedDescription)")
    }
  }

  private func loadContext() -> LobbyQuickAddContext? {
    guard let defaults = UserDefaults(suiteName: LobbyQuickAddStore.appGroupID),
          let data = defaults.data(forKey: LobbyQuickAddStore.key)
    else {
      return nil
    }
    return try? JSONDecoder().decode(LobbyQuickAddContext.self, from: data)
  }

  private func castVote(context: LobbyQuickAddContext, motionID: UUID) async throws {
    guard let encodedConflict = "motion_id,user_id".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "\(context.supabaseURL)/rest/v1/motion_votes?on_conflict=\(encodedConflict)") else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue(context.supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.addValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.addValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
    request.timeoutInterval = 12

    let payload: [String: Any] = [
      "motion_id": motionID.uuidString,
      "lobby_id": context.lobbyID.uuidString,
      "user_id": context.userID.uuidString,
      "vote": vote.rawValue,
      "voted_at": ISO8601DateFormatter().string(from: Date())
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw QuickAddIntentError(message: "No HTTP response from Supabase.")
    }
    guard (200..<300).contains(http.statusCode) else {
      let serverMessage = String(data: data, encoding: .utf8)?
        .replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown server error"
      throw QuickAddIntentError(message: "Supabase \(http.statusCode): \(serverMessage)")
    }
  }
}
