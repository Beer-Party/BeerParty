import XCTest
@testable import BeerParty

@MainActor
final class MadeItHomeOnceTests: XCTestCase {

  private let me = UUID()
  private let friend = UUID()

  private func row(_ name: String, by userID: UUID) -> LobbyDrink {
    LobbyDrink(
      id: UUID(),
      userId: userID,
      name: name,
      volumeMl: 0,
      abv: 0,
      consumedAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
  }

  private func homeRow(nickname: String, by userID: UUID) -> LobbyDrink {
    row("\(LobbyBackendService.madeItHomeDrinkPrefix)\(nickname)", by: userID)
  }

  func testNothingSentInAnEmptyLobby() {
    XCTAssertFalse(MadeItHomeOnce.hasSent(in: [], userID: me))
  }

  func testOwnHomeRowCounts() {
    let rows = [row("Beer", by: me), homeRow(nickname: "Lev", by: me)]
    XCTAssertTrue(MadeItHomeOnce.hasSent(in: rows, userID: me))
  }

  func testAFriendsHomeRowDoesNotCount() {
    let rows = [homeRow(nickname: "Paul", by: friend), row("Beer", by: me)]
    XCTAssertFalse(MadeItHomeOnce.hasSent(in: rows, userID: me))
  }

  func testAFriendWithTheSameNicknameDoesNotCount() {
    let rows = [homeRow(nickname: "Lev", by: friend)]
    XCTAssertFalse(MadeItHomeOnce.hasSent(in: rows, userID: me))
  }

  func testOwnRowCountsWhateverNicknameItCarries() {
    // Sent under an earlier nickname, or with an empty one.
    XCTAssertTrue(MadeItHomeOnce.hasSent(in: [homeRow(nickname: "Old name", by: me)], userID: me))
    XCTAssertTrue(MadeItHomeOnce.hasSent(in: [homeRow(nickname: "", by: me)], userID: me))
  }

  func testOtherOwnRowsDoNotCount() {
    let rows = [
      row("Beer", by: me),
      row("\(LobbyBackendService.lobbyClosedDrinkPrefix)2026-11-28T22:00:00Z|Lev", by: me),
      row("\(LobbyBackendService.motionArrivedDrinkPrefix)\(UUID().uuidString)|The pub", by: me)
    ]
    XCTAssertFalse(MadeItHomeOnce.hasSent(in: rows, userID: me))
  }

  func testUnknownUserHasSentNothing() {
    XCTAssertFalse(MadeItHomeOnce.hasSent(in: [homeRow(nickname: "Lev", by: me)], userID: nil))
  }
}
