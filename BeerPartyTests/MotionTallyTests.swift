import XCTest
@testable import BeerParty

@MainActor
final class MotionTallyTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private var later: Date { now.addingTimeInterval(600) }
  private var earlier: Date { now.addingTimeInterval(-600) }

  private func outcome(ayes: Int, votes: Int, members: Int, closesAt: Date? = nil) -> Bool? {
    MotionTally.outcome(
      ayeCount: ayes,
      voteCount: votes,
      memberCount: members,
      votingClosesAt: closesAt ?? later,
      now: now
    )
  }

  func testVotingStaysOpenWhileMembersAreMissingAndTimeIsLeft() {
    XCTAssertNil(outcome(ayes: 2, votes: 2, members: 5))
    XCTAssertNil(outcome(ayes: 0, votes: 0, members: 3))
  }

  func testDecidedAsSoonAsEveryoneHasVoted() {
    XCTAssertEqual(outcome(ayes: 3, votes: 3, members: 3), true)
    XCTAssertEqual(outcome(ayes: 0, votes: 3, members: 3), false)
  }

  func testDecidedWhenTheVotingTimeRunsOut() {
    XCTAssertEqual(outcome(ayes: 4, votes: 4, members: 5, closesAt: earlier), true)
    XCTAssertEqual(outcome(ayes: 1, votes: 1, members: 5, closesAt: earlier), false)
    // The closing moment itself counts as run out.
    XCTAssertEqual(outcome(ayes: 0, votes: 0, members: 5, closesAt: now), false)
  }

  // "More than two thirds": exactly two thirds is not enough.
  func testExactlyTwoThirdsDoesNotPass() {
    XCTAssertEqual(outcome(ayes: 2, votes: 3, members: 3), false)
    XCTAssertEqual(outcome(ayes: 4, votes: 6, members: 6), false)
    XCTAssertEqual(outcome(ayes: 3, votes: 4, members: 4), true)
    XCTAssertEqual(outcome(ayes: 5, votes: 6, members: 6), true)
  }

  // The share is of all members: silence counts against.
  func testMembersWhoDidNotVoteCountAgainst() {
    XCTAssertEqual(outcome(ayes: 3, votes: 3, members: 5, closesAt: earlier), false)
  }

  func testOneMemberDecidesAlone() {
    XCTAssertEqual(outcome(ayes: 1, votes: 1, members: 1), true)
    XCTAssertEqual(outcome(ayes: 0, votes: 1, members: 1), false)
  }

  // Before the member list has loaded, the lobby is counted as one member.
  func testNoKnownMembersCountsAsOne() {
    XCTAssertNil(outcome(ayes: 0, votes: 0, members: 0))
    XCTAssertEqual(outcome(ayes: 1, votes: 1, members: 0), true)
  }

  func testArrivalIsAnnouncedOnceForAPassedMotionWhoseTimeHasCome() {
    XCTAssertTrue(MotionTally.shouldAnnounceArrival(passed: true, targetAt: earlier, notifiedAt: nil, now: now))
    XCTAssertTrue(MotionTally.shouldAnnounceArrival(passed: true, targetAt: now, notifiedAt: nil, now: now))
  }

  func testArrivalIsNotAnnouncedEarlyTwiceOrForAFailedMotion() {
    XCTAssertFalse(MotionTally.shouldAnnounceArrival(passed: true, targetAt: later, notifiedAt: nil, now: now))
    XCTAssertFalse(MotionTally.shouldAnnounceArrival(passed: true, targetAt: earlier, notifiedAt: earlier, now: now))
    XCTAssertFalse(MotionTally.shouldAnnounceArrival(passed: false, targetAt: earlier, notifiedAt: nil, now: now))
    XCTAssertFalse(MotionTally.shouldAnnounceArrival(passed: nil, targetAt: earlier, notifiedAt: nil, now: now))
  }
}
