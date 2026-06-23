import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

struct LobbyLiveActivityService {
  func activeContext() -> LobbyQuickAddContext? {
    guard let defaults = UserDefaults(suiteName: LobbyQuickAddStore.appGroupID),
          let data = defaults.data(forKey: LobbyQuickAddStore.key)
    else {
      return nil
    }

    return try? JSONDecoder().decode(LobbyQuickAddContext.self, from: data)
  }

  func savedCustomPreset(lobbyID: UUID) -> QuickAddDrinkPreset? {
    guard let defaults = UserDefaults(suiteName: LobbyQuickAddStore.appGroupID),
          let data = defaults.data(forKey: LobbyQuickAddStore.customPresetKey(lobbyID: lobbyID))
    else {
      return nil
    }

    return try? JSONDecoder().decode(QuickAddDrinkPreset.self, from: data)
  }

  func saveCustomPreset(_ preset: QuickAddDrinkPreset, lobbyID: UUID) {
    guard let defaults = UserDefaults(suiteName: LobbyQuickAddStore.appGroupID),
          let data = try? JSONEncoder().encode(preset)
    else {
      return
    }

    defaults.set(data, forKey: LobbyQuickAddStore.customPresetKey(lobbyID: lobbyID))
  }

  func updateContext(
    lobbyID: UUID,
    lobbyName: String,
    userID: UUID,
    accessToken: String,
    lastCustomPreset: QuickAddDrinkPreset?,
    activeMotionID: UUID?,
    activeMotionTargetText: String?,
    shouldShowMotionVote: Bool
  ) {
    let context = LobbyQuickAddContext(
      lobbyID: lobbyID,
      lobbyName: lobbyName,
      userID: userID,
      accessToken: accessToken,
      supabaseURL: supabaseURLString,
      supabaseAnonKey: supabaseAnonKeyValue,
      lastCustomPreset: lastCustomPreset,
      activeMotionID: activeMotionID,
      activeMotionTargetText: activeMotionTargetText,
      shouldShowMotionVote: shouldShowMotionVote,
      updatedAt: Date()
    )

    if let defaults = UserDefaults(suiteName: LobbyQuickAddStore.appGroupID),
       let data = try? JSONEncoder().encode(context)
    {
      defaults.set(data, forKey: LobbyQuickAddStore.key)
    }

    #if canImport(ActivityKit)
    if #available(iOS 16.2, *) {
      Task { await upsertActivity(with: context) }
    }
    #endif
  }

  func endContext() {
    if let defaults = UserDefaults(suiteName: LobbyQuickAddStore.appGroupID) {
      defaults.removeObject(forKey: LobbyQuickAddStore.key)
    }

    #if canImport(ActivityKit)
    if #available(iOS 16.2, *) {
      Task {
        for activity in Activity<LobbyQuickAddActivityAttributes>.activities {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
      }
    }
    #endif
  }

  #if canImport(ActivityKit)
  @available(iOS 16.2, *)
  private func upsertActivity(with context: LobbyQuickAddContext) async {
    let attributes = LobbyQuickAddActivityAttributes(
      lobbyID: context.lobbyID.uuidString,
      lobbyName: context.lobbyName
    )

    let contentState = LobbyQuickAddActivityAttributes.ContentState(
      presets: QuickAddDrinkPreset.defaults,
      lastCustomPreset: context.lastCustomPreset,
      activeMotionID: context.activeMotionID?.uuidString,
      activeMotionTargetText: context.activeMotionTargetText,
      shouldShowMotionVote: context.shouldShowMotionVote ?? false,
      updatedAt: context.updatedAt
    )

    let staleDate = Date().addingTimeInterval(2 * 60 * 60)

    if let existing = Activity<LobbyQuickAddActivityAttributes>.activities.first {
      await existing.update(ActivityContent(state: contentState, staleDate: staleDate))
      return
    }

    _ = try? Activity<LobbyQuickAddActivityAttributes>.request(
      attributes: attributes,
      content: ActivityContent(state: contentState, staleDate: staleDate),
      pushType: nil
    )
  }
  #endif
}
