import XCTest
@testable import BeerParty

@MainActor
final class MotionServerClosingTests: XCTestCase {

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

  private func shouldAsk(_ motions: [LobbyMotion], members: Int = 4) -> Bool {
    MotionServerClosing.shouldAskServer(motions: motions, memberCount: members, now: now)
  }

  func testTheFunctionNameIsTheOneInTheDatabase() {
    XCTAssertEqual(MotionServerClosing.functionName, "close_expired_motions")
  }

  // The usual refresh: nothing is due, so the server is not asked.
  func testNoMotionsOrOnlyOpenVotesDoNotAsk() {
    XCTAssertFalse(shouldAsk([]))
    XCTAssertFalse(shouldAsk([motion(ayes: 1, neighs: 1)]))
  }

  func testMotionsAlreadyDecidedDoNotAsk() {
    let decided = motion(ayes: 4, closesInMinutes: -5, status: .closed, passed: true)
    XCTAssertFalse(shouldAsk([decided]))
  }

  func testAnOpenMotionWhoseVotingTimeIsOverAsks() {
    XCTAssertTrue(shouldAsk([motion(ayes: 1, closesInMinutes: -1)]))
    XCTAssertTrue(shouldAsk([motion(closesInMinutes: 0)]))
  }

  // Normally the database has closed such a motion already; if it is still
  // open (this phone's member list may be short), asking is harmless.
  func testAnOpenMotionEveryKnownMemberVotedOnAsks() {
    XCTAssertTrue(shouldAsk([motion(ayes: 2, neighs: 2)]))
  }

  func testOneDueMotionAmongOthersAsks() {
    let open = motion(ayes: 1)
    let decided = motion(ayes: 4, status: .closed, passed: true)
    let due = motion(ayes: 1, closesInMinutes: -2)
    XCTAssertTrue(shouldAsk([open, decided, due]))
  }

  func testFetchAgainOnlyWhenTheServerClosedSomething() {
    XCTAssertTrue(MotionServerClosing.shouldFetchAgain(closedByServer: 1))
    XCTAssertTrue(MotionServerClosing.shouldFetchAgain(closedByServer: 3))
    XCTAssertFalse(MotionServerClosing.shouldFetchAgain(closedByServer: 0))
  }

  // Not asked, or the request failed: nothing new to read; the next refresh
  // tries again.
  func testNoAnswerMeansNoSecondFetch() {
    XCTAssertFalse(MotionServerClosing.shouldFetchAgain(closedByServer: nil))
  }
}
