import XCTest
@testable import BeerParty

@MainActor
final class LobbyQuickAddStoreTests: XCTestCase {

  /// Runs the test body against a throwaway store, never the real app group.
  private func withTemporaryDefaults(_ body: (UserDefaults) throws -> Void) throws {
    let suiteName = "LobbyQuickAddStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    try body(defaults)
  }

  func testRemoveContextDeletesTheSavedContext() throws {
    try withTemporaryDefaults { defaults in
      defaults.set(Data("context with a token".utf8), forKey: LobbyQuickAddStore.key)

      LobbyQuickAddStore.removeContext(from: defaults)

      XCTAssertNil(defaults.data(forKey: LobbyQuickAddStore.key))
    }
  }

  // The custom drink is not account data and is offered again in the next lobby session.
  func testRemoveContextKeepsTheCustomPresets() throws {
    try withTemporaryDefaults { defaults in
      let presetKey = LobbyQuickAddStore.customPresetKey(lobbyID: UUID())
      defaults.set(Data("context with a token".utf8), forKey: LobbyQuickAddStore.key)
      defaults.set(Data("preset".utf8), forKey: presetKey)

      LobbyQuickAddStore.removeContext(from: defaults)

      XCTAssertEqual(defaults.data(forKey: presetKey), Data("preset".utf8))
    }
  }

  func testRemoveContextWithNothingSavedOrNoStoreDoesNothing() throws {
    try withTemporaryDefaults { defaults in
      LobbyQuickAddStore.removeContext(from: defaults)
      LobbyQuickAddStore.removeContext(from: nil)

      XCTAssertNil(defaults.data(forKey: LobbyQuickAddStore.key))
    }
  }
}
