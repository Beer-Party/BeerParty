import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

struct QuickAddDrinkPreset: Codable, Hashable {
  let id: String
  let name: String
  let volumeMl: Double
  let abv: Double

  static let beer = QuickAddDrinkPreset(id: "beer", name: "Beer", volumeMl: 330, abv: 5)
  static let wine = QuickAddDrinkPreset(id: "wine", name: "Wine", volumeMl: 150, abv: 12)
  static let shot = QuickAddDrinkPreset(id: "shot", name: "Shot", volumeMl: 44, abv: 40)
  static let water = QuickAddDrinkPreset(id: "water", name: "Water", volumeMl: 250, abv: 0)

  static let defaults: [QuickAddDrinkPreset] = [.beer, .wine, .shot, .water]
}

/// Why a Lock Screen quick-add action did not work, and the sentence shown for
/// it. The dialog appears on the Lock Screen, so it says what to do and never
/// shows a status code or the server's reply.
enum QuickAddFailure: Error, Equatable {
  /// The saved sign-in is no longer accepted. Opening the app renews it.
  case signInExpired
  case offline
  case other

  static let noLobbyMessage = "No lobby is active. Open a lobby in BeerParty first."

  static func from(statusCode: Int) -> QuickAddFailure {
    statusCode == 401 ? .signInExpired : .other
  }

  static func from(error: Error) -> QuickAddFailure {
    if let failure = error as? QuickAddFailure {
      return failure
    }
    guard let urlError = error as? URLError else {
      return .other
    }
    switch urlError.code {
    case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
         .internationalRoamingOff, .timedOut, .cannotFindHost, .cannotConnectToHost,
         .dnsLookupFailed:
      return .offline
    default:
      return .other
    }
  }

  /// - Parameter action: what was attempted, worded to follow "Couldn't", for
  ///   example "add the drink".
  func message(couldNot action: String) -> String {
    switch self {
    case .signInExpired:
      return "Couldn't \(action). Open BeerParty, then try again."
    case .offline:
      return "Couldn't \(action). You seem to be offline."
    case .other:
      return "Couldn't \(action). Please try again."
    }
  }
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
  static let customPresetKeyPrefix = "lobby.quickadd.custom."

  static func customPresetKey(lobbyID: UUID) -> String {
    "\(customPresetKeyPrefix)\(lobbyID.uuidString)"
  }
}

#if canImport(ActivityKit)
@available(iOS 16.2, *)
struct LobbyQuickAddActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let presets: [QuickAddDrinkPreset]
    let lastCustomPreset: QuickAddDrinkPreset?
    let activeMotionID: String?
    let activeMotionTargetText: String?
    let shouldShowMotionVote: Bool?
    let updatedAt: Date
  }

  let lobbyID: String
  let lobbyName: String
}
#endif
