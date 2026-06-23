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
