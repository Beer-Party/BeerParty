import XCTest
@testable import BeerParty

@MainActor
final class LiveBACRowsTests: XCTestCase {

  private let me = UUID()
  private let anna = UUID()
  private let ben = UUID()

  private func snapshot(_ userID: UUID, _ nickname: String, _ bac: Double) -> MemberBACSnapshot {
    MemberBACSnapshot(userId: userID, nickname: nickname, bac: bac)
  }

  private func member(_ userID: UUID, _ nickname: String, pic: String? = nil) -> LobbyMemberData {
    LobbyMemberData(userId: userID, nickname: nickname, profilePicPath: pic)
  }

  // MARK: bar length

  func testTheHighestMemberGetsAFullBar() {
    XCTAssertEqual(LiveBACRows.barFraction(bac: 1.2, highest: 1.2), 1, accuracy: 0.0001)
  }

  func testTheOthersAreMeasuredAgainstTheHighest() {
    XCTAssertEqual(LiveBACRows.barFraction(bac: 0.6, highest: 1.2), 0.5, accuracy: 0.0001)
  }

  // One beer in an otherwise sober lobby must not fill the whole bar.
  func testALowHighestIsMeasuredAgainstHalfAPromille() {
    XCTAssertEqual(LiveBACRows.smallestFullBar, 0.5)
    XCTAssertEqual(LiveBACRows.barFraction(bac: 0.1, highest: 0.1), 0.2, accuracy: 0.0001)
  }

  func testASoberMemberHasNoBar() {
    XCTAssertEqual(LiveBACRows.barFraction(bac: 0, highest: 1.2), 0)
    XCTAssertEqual(LiveBACRows.barFraction(bac: 0, highest: 0), 0)
  }

  func testTheBarNeverLeavesItsRange() {
    XCTAssertEqual(LiveBACRows.barFraction(bac: 3, highest: 1), 1)
    XCTAssertEqual(LiveBACRows.barFraction(bac: -0.2, highest: 1), 0)
    XCTAssertEqual(LiveBACRows.barFraction(bac: .nan, highest: 1), 0)
  }

  // MARK: rows

  func testRowsKeepTheOrderOfTheSnapshot() {
    let rows = LiveBACRows.rows(
      current: [snapshot(anna, "Anna", 0.9), snapshot(me, "Me", 0.45), snapshot(ben, "Ben", 0)],
      members: [member(me, "Me"), member(anna, "Anna"), member(ben, "Ben")],
      currentUserID: me
    )

    XCTAssertEqual(rows.map(\.nickname), ["Anna", "Me", "Ben"])
    XCTAssertEqual(rows.map(\.bac), [0.9, 0.45, 0])
    XCTAssertEqual(rows[0].barFraction, 1, accuracy: 0.0001)
    XCTAssertEqual(rows[1].barFraction, 0.5, accuracy: 0.0001)
    XCTAssertEqual(rows[2].barFraction, 0)
  }

  func testOnlyTheSignedInUserIsMarked() {
    let rows = LiveBACRows.rows(
      current: [snapshot(anna, "Anna", 0.9), snapshot(me, "Me", 0.45)],
      members: [member(me, "Me"), member(anna, "Anna")],
      currentUserID: me
    )
    XCTAssertEqual(rows.map(\.isCurrentUser), [false, true])
  }

  func testNobodyIsMarkedWhileTheUserIsNotKnown() {
    let rows = LiveBACRows.rows(
      current: [snapshot(anna, "Anna", 0.9)],
      members: [member(anna, "Anna")],
      currentUserID: nil
    )
    XCTAssertEqual(rows.map(\.isCurrentUser), [false])
  }

  func testThePhotoComesFromTheMemberList() {
    let rows = LiveBACRows.rows(
      current: [snapshot(anna, "Anna", 0.9), snapshot(ben, "Ben", 0.1), snapshot(me, "Me", 0)],
      members: [member(anna, "Anna", pic: "a/avatar.jpg"), member(ben, "Ben", pic: ""), member(me, "Me")],
      currentUserID: me
    )
    XCTAssertEqual(rows.map(\.profilePicPath), ["a/avatar.jpg", nil, nil])
  }

  func testNoMembersGiveNoRows() {
    XCTAssertEqual(LiveBACRows.rows(current: [], members: [], currentUserID: me), [])
  }
}
