import XCTest
@testable import BeerParty

@MainActor
final class LobbyListItemTests: XCTestCase {

  private let base = Date(timeIntervalSince1970: 1_800_000_000)

  private func item(_ name: String, active: Bool, daysAgo: Double?) -> LobbyListItem {
    LobbyListItem(
      destination: LobbyDestination(lobbyID: UUID(), lobbyName: name),
      isActive: active,
      memberCount: 2,
      createdAt: daysAgo.map { base.addingTimeInterval(-$0 * 86_400) }
    )
  }

  private func names(_ items: [LobbyListItem]) -> [String] {
    items.map(\.destination.lobbyName)
  }

  func testOpenLobbiesComeBeforeClosedOnes() {
    let sorted = LobbyListItem.sorted([
      item("closed, new", active: false, daysAgo: 1),
      item("open, old", active: true, daysAgo: 30),
    ])
    XCTAssertEqual(names(sorted), ["open, old", "closed, new"])
  }

  func testNewestFirstWithinEachGroup() {
    let sorted = LobbyListItem.sorted([
      item("open 5", active: true, daysAgo: 5),
      item("closed 9", active: false, daysAgo: 9),
      item("open 1", active: true, daysAgo: 1),
      item("closed 2", active: false, daysAgo: 2),
    ])
    XCTAssertEqual(names(sorted), ["open 1", "open 5", "closed 2", "closed 9"])
  }

  func testLobbyWithoutADateCountsAsOldest() {
    let sorted = LobbyListItem.sorted([
      item("no date", active: false, daysAgo: nil),
      item("dated", active: false, daysAgo: 400),
    ])
    XCTAssertEqual(names(sorted), ["dated", "no date"])
  }

  // The bug this replaces: one failed request emptied the list.
  func testFailedReloadKeepsTheRowsAlreadyShown() {
    let shown = [item("a", active: true, daysAgo: 1), item("b", active: false, daysAgo: 2)]
    let after = LobbyListItem.afterReload(shown: shown, loaded: nil)
    XCTAssertEqual(after.map(\.id), shown.map(\.id))
  }

  func testSuccessfulReloadReplacesAndSortsTheRows() {
    let shown = [item("old", active: true, daysAgo: 1)]
    let loaded = [item("closed", active: false, daysAgo: 1), item("open", active: true, daysAgo: 3)]
    let after = LobbyListItem.afterReload(shown: shown, loaded: loaded)
    XCTAssertEqual(names(after), ["open", "closed"])
  }

  // Leaving the last lobby is a real result, not a failure: the list empties.
  func testSuccessfulReloadWithNoLobbiesEmptiesTheList() {
    let shown = [item("old", active: true, daysAgo: 1)]
    XCTAssertTrue(LobbyListItem.afterReload(shown: shown, loaded: []).isEmpty)
  }
}
