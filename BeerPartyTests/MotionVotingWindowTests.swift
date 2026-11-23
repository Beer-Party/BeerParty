import XCTest
@testable import BeerParty

@MainActor
final class MotionVotingWindowTests: XCTestCase {

  private let created = Date(timeIntervalSince1970: 1_800_000_000)

  private func closes(targetInMinutes minutes: Double) -> Date {
    MotionTally.votingClosesAt(
      createdAt: created,
      targetAt: created.addingTimeInterval(minutes * 60)
    )
  }

  // The bug: "in 5 min" kept voting open for ten, so it was announced late.
  func testAFiveMinuteMotionClosesVotingAtItsOwnTime() {
    XCTAssertEqual(closes(targetInMinutes: 5), created.addingTimeInterval(5 * 60))
  }

  func testATenMinuteMotionClosesVotingAfterTenMinutes() {
    XCTAssertEqual(closes(targetInMinutes: 10), created.addingTimeInterval(10 * 60))
  }

  func testLaterMotionsStillCloseVotingAfterTenMinutes() {
    XCTAssertEqual(closes(targetInMinutes: 15), created.addingTimeInterval(10 * 60))
    XCTAssertEqual(closes(targetInMinutes: 45), created.addingTimeInterval(10 * 60))
  }

  // The database requires voting to close no earlier than the motion was made.
  func testVotingNeverClosesBeforeTheMotionWasMade() {
    XCTAssertEqual(closes(targetInMinutes: 0), created)
    XCTAssertEqual(closes(targetInMinutes: -3), created)
  }

  // With voting closed at the motion's time, an undecided five-minute motion
  // is decided, and can be announced, at that time.
  func testAFiveMinuteMotionIsDecidedAtItsTime() {
    let targetAt = created.addingTimeInterval(5 * 60)
    let closesAt = MotionTally.votingClosesAt(createdAt: created, targetAt: targetAt)
    let passed = MotionTally.outcome(
      ayeCount: 3, voteCount: 3, memberCount: 4, votingClosesAt: closesAt, now: targetAt)
    XCTAssertEqual(passed, true)
    XCTAssertTrue(MotionTally.shouldAnnounceArrival(
      passed: passed, targetAt: targetAt, notifiedAt: nil, now: targetAt))
  }
}
