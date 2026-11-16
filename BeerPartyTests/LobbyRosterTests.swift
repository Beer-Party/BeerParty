import XCTest
@testable import BeerParty

@MainActor
final class LobbyRosterTests: XCTestCase {

  func testSameMembersInAnyOrderNeedNoReload() {
    let a = UUID()
    let b = UUID()
    XCTAssertFalse(LobbyRoster.needsReload(shownMemberIDs: [a, b], latestMemberIDs: [b, a]))
    XCTAssertFalse(LobbyRoster.needsReload(shownMemberIDs: [], latestMemberIDs: []))
  }

  func testMemberJoiningNeedsReload() {
    let a = UUID()
    XCTAssertTrue(LobbyRoster.needsReload(shownMemberIDs: [a], latestMemberIDs: [a, UUID()]))
  }

  func testMemberLeavingNeedsReload() {
    let a = UUID()
    XCTAssertTrue(LobbyRoster.needsReload(shownMemberIDs: [a, UUID()], latestMemberIDs: [a]))
  }
}
