import XCTest
@testable import BeerParty

@MainActor
final class MotionClosingsTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private let lobbyID = UUID()

  private func motion(
    ayes: Int = 0,
    neighs: Int = 0,
    closesInMinutes: Double = 5,
    status: MotionStatus = .active,
    passed: Bool? = nil
  ) -> LobbyMotion {
    let id = UUID()
    let choices = Array(repeating: MotionVoteChoice.aye, count: ayes)
      + Array(repeating: MotionVoteChoice.neigh, count: neighs)
    let votes = choices.map {
      LobbyMotionVote(motionId: id, userId: UUID(), vote: $0, votedAt: now.addingTimeInterval(-60))
    }
    return LobbyMotion(
      id: id,
      lobbyId: lobbyID,
      createdBy: UUID(),
      proposerNickname: "Ada",
      targetText: "the kebab place",
      delayMinutes: 15,
      createdAt: now.addingTimeInterval(-300),
      targetAt: now.addingTimeInterval(600),
      votingClosesAt: now.addingTimeInterval(closesInMinutes * 60),
      status: status,
      passed: passed,
      resolvedAt: status == .closed ? now.addingTimeInterval(-30) : nil,
      notifiedAt: nil,
      votes: votes
    )
  }

  // The usual refresh: nothing to close, so no second fetch.
  func testNoMotionsMeansNothingToClose() {
    XCTAssertEqual(MotionTally.closings(for: [], memberCount: 4, now: now), [])
  }

  func testAnOpenVoteIsNotClosed() {
    let open = motion(ayes: 1, neighs: 1)
    XCTAssertEqual(MotionTally.closings(for: [open], memberCount: 4, now: now), [])
  }

  func testMotionsAlreadyDecidedAreLeftAlone() {
    let decided = motion(ayes: 4, closesInMinutes: -5, status: .closed, passed: true)
    XCTAssertEqual(MotionTally.closings(for: [decided], memberCount: 4, now: now), [])
  }

  func testAMotionEveryoneVotedOnIsClosedWithItsResult() {
    let passing = motion(ayes: 3, neighs: 1)
    let failing = motion(ayes: 2, neighs: 2)

    XCTAssertEqual(
      MotionTally.closings(for: [passing], memberCount: 4, now: now),
      [MotionTally.Closing(motionID: passing.id, passed: true)]
    )
    XCTAssertEqual(
      MotionTally.closings(for: [failing], memberCount: 4, now: now),
      [MotionTally.Closing(motionID: failing.id, passed: false)]
    )
  }

  // Silence counts against: one aye of four members does not pass.
  func testAMotionWhoseVotingTimeRanOutIsClosed() {
    let expired = motion(ayes: 1, closesInMinutes: -1)
    XCTAssertEqual(
      MotionTally.closings(for: [expired], memberCount: 4, now: now),
      [MotionTally.Closing(motionID: expired.id, passed: false)]
    )
  }

  func testOnlyTheMotionsThatAreDueAreReturned() {
    let open = motion(ayes: 1)
    let decided = motion(ayes: 4, status: .closed, passed: true)
    let due = motion(ayes: 4)

    XCTAssertEqual(
      MotionTally.closings(for: [open, decided, due], memberCount: 4, now: now),
      [MotionTally.Closing(motionID: due.id, passed: true)]
    )
  }
}
