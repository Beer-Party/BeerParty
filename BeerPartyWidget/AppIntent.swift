import Foundation
import ActivityKit
import AppIntents

// QuickAddDrinkPreset, LobbyQuickAddContext and LobbyQuickAddStore come from
// BeerParty/Core/Models/LockScreenQuickAdd.swift, which is a member of both the
// app and the widget extension.

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
      return .result(dialog: "\(QuickAddFailure.noLobbyMessage)")
    }

    guard let selected = selectedPreset(from: context) else {
      return .result(dialog: "Custom drink unavailable.")
    }

    // The app refuses drinks for a closed lobby; a locked phone never opened the
    // lobby screen to find out, so ask here. Without an answer, carry on as before.
    if await lobbyOpenState(context: context) == .closed {
      await endLiveActivity()
      return .result(dialog: "This lobby is closed. Drinks can no longer be added.")
    }

    do {
      try await insertDrink(context: context, preset: selected)
      return .result(dialog: "Added \(selected.name).")
    } catch {
      let message = QuickAddFailure.from(error: error).message(couldNot: "add the drink")
      return .result(dialog: "\(message)")
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
      return .beer
    case .wine:
      return .wine
    case .shot:
      return .shot
    case .water:
      return .water
    case .custom:
      return context.lastCustomPreset
    }
  }

  private func lobbyOpenState(context: LobbyQuickAddContext) async -> LobbyOpenState {
    guard var components = URLComponents(string: "\(context.supabaseURL)/rest/v1/lobbies") else {
      return .unknown
    }
    components.queryItems = [
      URLQueryItem(name: "select", value: "is_active,created_at"),
      URLQueryItem(name: "id", value: "eq.\(context.lobbyID.uuidString)")
    ]
    guard let url = components.url else {
      return .unknown
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue(context.supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.addValue("Bearer \(context.accessToken)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 6

    guard let (data, response) = try? await URLSession.shared.data(for: request),
          let http = response as? HTTPURLResponse
    else {
      return .unknown
    }
    return LobbyOpenState.from(statusCode: http.statusCode, body: data, now: Date())
  }

  private func endLiveActivity() async {
    for activity in Activity<LobbyQuickAddActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
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

    let (_, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw QuickAddFailure.other
    }

    guard (200..<300).contains(http.statusCode) else {
      throw QuickAddFailure.from(statusCode: http.statusCode)
    }
  }
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
      return .result(dialog: "\(QuickAddFailure.noLobbyMessage)")
    }

    guard (context.shouldShowMotionVote ?? false), let motionID = context.activeMotionID else {
      return .result(dialog: "No active motion to vote on.")
    }

    do {
      try await castVote(context: context, motionID: motionID)
      let label = vote == .aye ? "Aye" : "Neigh"
      return .result(dialog: "\(label) vote submitted.")
    } catch {
      let message = QuickAddFailure.from(error: error).message(couldNot: "send your vote")
      return .result(dialog: "\(message)")
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

    let (_, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw QuickAddFailure.other
    }
    guard (200..<300).contains(http.statusCode) else {
      throw QuickAddFailure.from(statusCode: http.statusCode)
    }
  }
}
