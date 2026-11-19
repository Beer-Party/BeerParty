import XCTest
@testable import BeerParty

@MainActor
final class BuddyComparisonTests: XCTestCase {

  private let me = UUID()
  private let buddy = UUID()

  private func members(myBAC: Double, buddyBAC: Double) -> [MemberBACSnapshot] {
    [
      MemberBACSnapshot(userId: me, nickname: "Me", bac: myBAC),
      MemberBACSnapshot(userId: buddy, nickname: "Sam", bac: buddyBAC)
    ]
  }

  private func compare(
    myBAC: Double,
    buddyBAC: Double,
    params: LobbyBACParamsData? = nil
  ) -> BuddyComparisonData? {
    BuddyComparison.compare(
      current: members(myBAC: myBAC, buddyBAC: buddyBAC),
      currentUserID: me,
      buddyID: buddy,
      currentUserParams: params
    )
  }

  func testNoBuddyChosenGivesNoComparison() {
    XCTAssertNil(
      BuddyComparison.compare(
        current: members(myBAC: 0.5, buddyBAC: 0.2),
        currentUserID: me,
        buddyID: nil,
        currentUserParams: nil
      )
    )
  }

  func testBuddyOrCurrentUserMissingFromTheSnapshotGivesNoComparison() {
    let onlyMe = [MemberBACSnapshot(userId: me, nickname: "Me", bac: 0.5)]
    XCTAssertNil(
      BuddyComparison.compare(current: onlyMe, currentUserID: me, buddyID: buddy, currentUserParams: nil)
    )

    let onlyBuddy = [MemberBACSnapshot(userId: buddy, nickname: "Sam", bac: 0.5)]
    XCTAssertNil(
      BuddyComparison.compare(current: onlyBuddy, currentUserID: me, buddyID: buddy, currentUserParams: nil)
    )
  }

  func testAheadWhenMyBACIsHigher() throws {
    let result = try XCTUnwrap(compare(myBAC: 0.8, buddyBAC: 0.3))
    XCTAssertEqual(result.buddyNickname, "Sam")
    XCTAssertEqual(result.bacGap, 0.5, accuracy: 0.0001)
    XCTAssertTrue(result.isAhead)
    XCTAssertFalse(result.isEven)
  }

  func testBehindWhenMyBACIsLowerAndTheGapStaysPositive() throws {
    let result = try XCTUnwrap(compare(myBAC: 0.3, buddyBAC: 0.8))
    XCTAssertEqual(result.bacGap, 0.5, accuracy: 0.0001)
    XCTAssertFalse(result.isAhead)
  }

  func testEvenWhenTheGapIsUnderOneHundredth() throws {
    let result = try XCTUnwrap(compare(myBAC: 0.505, buddyBAC: 0.5))
    XCTAssertTrue(result.isEven)

    let notEven = try XCTUnwrap(compare(myBAC: 0.52, buddyBAC: 0.5))
    XCTAssertFalse(notEven.isEven)
  }

  // gap in grams = gap in promille x body water / 0.84; one beer is 330 ml at 5 %.
  func testBeerGapUsesTheCurrentUsersBodyWater() throws {
    let params = LobbyBACParamsData(userId: me, tbw: 42, eliminationPerHourPromille: 0.15)
    let result = try XCTUnwrap(compare(myBAC: 0.9, buddyBAC: 0.4, params: params))

    let expectedGrams = 0.5 * 42 / 0.84
    XCTAssertEqual(result.standardBeerGap, expectedGrams / (330.0 * 0.05 * 0.789), accuracy: 0.0001)
  }

  // Without saved parameters the calculator's default body water (40) is used.
  func testBeerGapFallsBackToDefaultParameters() throws {
    let result = try XCTUnwrap(compare(myBAC: 0.9, buddyBAC: 0.4))

    let expectedGrams = 0.5 * 40 / 0.84
    XCTAssertEqual(result.standardBeerGap, expectedGrams / BuddyComparison.standardBeerGrams, accuracy: 0.0001)
  }
}
