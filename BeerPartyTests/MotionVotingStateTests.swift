import XCTest
@testable import BeerParty

@MainActor
final class MotionVotingStateTests: XCTestCase {

  private func state(status: Int = 200, json: String) -> MotionVotingState {
    MotionVotingState.from(statusCode: status, body: Data(json.utf8))
  }

  func testAnActiveMotionIsOpenForVotes() {
    XCTAssertEqual(state(json: #"[{"status":"active"}]"#), .open)
  }

  func testADecidedMotionIsOver() {
    XCTAssertEqual(state(json: #"[{"status":"closed"}]"#), .over)
  }

  // The request worked and found no motion: it was deleted with its lobby.
  func testAMotionThatIsGoneIsOver() {
    XCTAssertEqual(state(json: "[]"), .over)
  }

  // Without an answer the vote is still tried, as before.
  func testNoUsableAnswerIsUnknown() {
    XCTAssertEqual(state(status: 401, json: #"{"message":"JWT expired"}"#), .unknown)
    XCTAssertEqual(state(status: 500, json: ""), .unknown)
    XCTAssertEqual(state(json: "not json"), .unknown)
    XCTAssertEqual(state(json: #"[{"other":"active"}]"#), .unknown)
  }

  // MARK: - Hiding the vote buttons

  private let motionID = UUID()
  private let savedAt = Date(timeIntervalSince1970: 1_800_000_000)

  private func contextWithVoteButtons() -> LobbyQuickAddContext {
    LobbyQuickAddContext(
      lobbyID: UUID(),
      lobbyName: "Friday",
      userID: UUID(),
      accessToken: "token",
      supabaseURL: "https://example.invalid",
      supabaseAnonKey: "anon",
      lastCustomPreset: QuickAddDrinkPreset(id: "custom", name: "Cider", volumeMl: 500, abv: 4.5),
      activeMotionID: motionID,
      activeMotionTargetText: "the kebab place",
      shouldShowMotionVote: true,
      updatedAt: savedAt
    )
  }

  func testHidingTheVoteButtonsChangesNothingElse() {
    let before = contextWithVoteButtons()
    let later = savedAt.addingTimeInterval(90)

    let after = before.hidingMotionVote(now: later)

    XCTAssertEqual(after.shouldShowMotionVote, false)
    XCTAssertEqual(after.updatedAt, later)
    XCTAssertEqual(after.lobbyID, before.lobbyID)
    XCTAssertEqual(after.lobbyName, before.lobbyName)
    XCTAssertEqual(after.userID, before.userID)
    XCTAssertEqual(after.accessToken, before.accessToken)
    XCTAssertEqual(after.supabaseURL, before.supabaseURL)
    XCTAssertEqual(after.supabaseAnonKey, before.supabaseAnonKey)
    XCTAssertEqual(after.lastCustomPreset, before.lastCustomPreset)
    XCTAssertEqual(after.activeMotionID, motionID)
    XCTAssertEqual(after.activeMotionTargetText, "the kebab place")
  }

  // What the vote button reads on its next tap is what was saved.
  func testTheHiddenButtonsAreSavedAndReadBack() throws {
    let suiteName = "MotionVotingStateTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    XCTAssertNil(LobbyQuickAddStore.loadContext(from: defaults))

    let context = contextWithVoteButtons()
    LobbyQuickAddStore.saveContext(context, to: defaults)
    XCTAssertEqual(LobbyQuickAddStore.loadContext(from: defaults)?.shouldShowMotionVote, true)

    LobbyQuickAddStore.saveContext(context.hidingMotionVote(now: savedAt), to: defaults)
    let reread = try XCTUnwrap(LobbyQuickAddStore.loadContext(from: defaults))
    XCTAssertEqual(reread.shouldShowMotionVote, false)
    XCTAssertEqual(reread.activeMotionID, motionID)
    XCTAssertEqual(reread.accessToken, "token")
  }

  func testSavingWithoutAStoreDoesNothing() {
    LobbyQuickAddStore.saveContext(contextWithVoteButtons(), to: nil)
    XCTAssertNil(LobbyQuickAddStore.loadContext(from: nil))
  }
}
