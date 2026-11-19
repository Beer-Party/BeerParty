import XCTest
@testable import BeerParty

@MainActor
final class LobbyQuickAddStoreTests: XCTestCase {
  private var suiteName = ""
  private var defaults: UserDefaults!

  override func setUp() {
    super.setUp()
    suiteName = "LobbyQuickAddStoreTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    defaults = nil
    super.tearDown()
  }

  func testRemoveContextDeletesTheSavedContext() {
    defaults.set(Data("context with a token".utf8), forKey: LobbyQuickAddStore.key)

    LobbyQuickAddStore.removeContext(from: defaults)

    XCTAssertNil(defaults.data(forKey: LobbyQuickAddStore.key))
  }

  // The custom drink is not account data and is offered again in the next lobby session.
  func testRemoveContextKeepsTheCustomPresets() {
    let presetKey = LobbyQuickAddStore.customPresetKey(lobbyID: UUID())
    defaults.set(Data("context with a token".utf8), forKey: LobbyQuickAddStore.key)
    defaults.set(Data("preset".utf8), forKey: presetKey)

    LobbyQuickAddStore.removeContext(from: defaults)

    XCTAssertEqual(defaults.data(forKey: presetKey), Data("preset".utf8))
  }

  func testRemoveContextWithNothingSavedOrNoStoreDoesNothing() {
    LobbyQuickAddStore.removeContext(from: defaults)
    LobbyQuickAddStore.removeContext(from: nil)

    XCTAssertNil(defaults.data(forKey: LobbyQuickAddStore.key))
  }
}
