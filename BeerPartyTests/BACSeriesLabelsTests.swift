import XCTest
@testable import BeerParty

@MainActor
final class BACSeriesLabelsTests: XCTestCase {
  // Fixed ids, so "first in user-id order" is known.
  private let idA = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000000")!
  private let idB = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000000")!
  private let idC = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000000")!

  private func member(_ id: UUID, _ nickname: String) -> LobbyMemberData {
    LobbyMemberData(userId: id, nickname: nickname, profilePicPath: nil)
  }

  func testDifferentNicknamesAreKept() {
    let labels = BACSeriesLabels.labels(for: [member(idA, "Anna"), member(idB, "Ben")])
    XCTAssertEqual(labels, [idA: "Anna", idB: "Ben"])
  }

  func testNoMembersGivesNoLabels() {
    XCTAssertTrue(BACSeriesLabels.labels(for: []).isEmpty)
  }

  func testSameNicknameIsNumberedInUserIDOrder() {
    let expected = [idA: "Anna", idB: "Anna (2)", idC: "Anna (3)"]
    XCTAssertEqual(
      BACSeriesLabels.labels(for: [member(idA, "Anna"), member(idB, "Anna"), member(idC, "Anna")]),
      expected
    )
    // The order the members arrive in does not change who gets which number.
    XCTAssertEqual(
      BACSeriesLabels.labels(for: [member(idC, "Anna"), member(idB, "Anna"), member(idA, "Anna")]),
      expected
    )
  }

  func testCapitalsAndSpacesDoNotMakeANicknameDifferent() {
    let labels = BACSeriesLabels.labels(for: [member(idA, "Anna"), member(idB, "anna ")])
    XCTAssertEqual(labels[idA], "Anna")
    XCTAssertEqual(labels[idB], "anna (2)")
  }

  func testNumberedLabelNeverCollidesWithARealNickname() {
    let labels = BACSeriesLabels.labels(
      for: [member(idA, "Anna"), member(idB, "Anna"), member(idC, "Anna (2)")]
    )
    XCTAssertEqual(labels, [idA: "Anna", idB: "Anna (3)", idC: "Anna (2)"])
  }

  func testEveryLabelIsUnique() {
    let members = [
      member(idA, "Sam"), member(idB, "Sam"), member(idC, "Sam"),
      member(UUID(), "Sam (2)"), member(UUID(), "Alex")
    ]
    let labels = BACSeriesLabels.labels(for: members)
    XCTAssertEqual(labels.count, members.count)
    XCTAssertEqual(Set(labels.values).count, members.count)
  }
}
