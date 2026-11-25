import XCTest
@testable import BeerParty

@MainActor
final class MadeItHomeWindowTests: XCTestCase {

  private let closedAt = Date(timeIntervalSince1970: 1_800_000_000)

  private func canSend(isActive: Bool = false, closedAt: Date?, hoursLater: Double) -> Bool {
    MadeItHomeWindow.canSend(
      isLobbyActive: isActive,
      closedAt: closedAt,
      now: self.closedAt.addingTimeInterval(hoursLater * 3600)
    )
  }

  func testOpenLobbyAlwaysAllows() {
    XCTAssertTrue(canSend(isActive: true, closedAt: nil, hoursLater: 0))
    XCTAssertTrue(canSend(isActive: true, closedAt: closedAt, hoursLater: 30))
  }

  // The usual case: closing time, then everybody walks home.
  func testJustAfterClosingAllows() {
    XCTAssertTrue(canSend(closedAt: closedAt, hoursLater: 0))
    XCTAssertTrue(canSend(closedAt: closedAt, hoursLater: 0.5))
    XCTAssertTrue(canSend(closedAt: closedAt, hoursLater: 4.99))
  }

  // The other phones stop reading new rows after 5 hours.
  func testFiveHoursAfterClosingRefuses() {
    XCTAssertFalse(canSend(closedAt: closedAt, hoursLater: 5))
    XCTAssertFalse(canSend(closedAt: closedAt, hoursLater: 24))
  }

  // The closing note comes from another phone, whose clock can be ahead.
  func testClosingTimeSlightlyAheadOfThisClockAllows() {
    XCTAssertTrue(canSend(closedAt: closedAt, hoursLater: -0.05))
  }

  // For example after the 24-hour auto-close, which writes no closing note.
  func testClosedLobbyWithoutClosingTimeRefuses() {
    XCTAssertFalse(canSend(closedAt: nil, hoursLater: 0))
  }

  func testWindowMatchesTheLiveUpdatesAfterClosing() {
    XCTAssertEqual(MadeItHomeWindow.liveUpdatesAfterClosing, 5 * 60 * 60)
  }
}
