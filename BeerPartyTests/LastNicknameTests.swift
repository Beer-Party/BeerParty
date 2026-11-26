import XCTest
@testable import BeerParty

@MainActor
final class LastNicknameTests: XCTestCase {

  /// Runs the test body against a throwaway store, never the app's own.
  private func withTemporaryDefaults(_ body: (UserDefaults) throws -> Void) throws {
    let suiteName = "LastNicknameTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    try body(defaults)
  }

  func testThereIsNoNicknameAtFirst() throws {
    try withTemporaryDefaults { defaults in
      XCTAssertEqual(LastNickname.load(from: defaults), "")
    }
  }

  func testASavedNicknameIsLoadedAgain() throws {
    try withTemporaryDefaults { defaults in
      LastNickname.save("Anna", to: defaults)
      XCTAssertEqual(LastNickname.load(from: defaults), "Anna")
    }
  }

  func testTheNicknameIsSavedWithoutSurroundingSpaces() throws {
    try withTemporaryDefaults { defaults in
      LastNickname.save("  Anna B \n", to: defaults)
      XCTAssertEqual(LastNickname.load(from: defaults), "Anna B")
    }
  }

  func testAnEmptyNicknameDoesNotReplaceTheSavedOne() throws {
    try withTemporaryDefaults { defaults in
      LastNickname.save("Anna", to: defaults)
      LastNickname.save("   ", to: defaults)
      XCTAssertEqual(LastNickname.load(from: defaults), "Anna")
    }
  }

  func testTheNewestNicknameWins() throws {
    try withTemporaryDefaults { defaults in
      LastNickname.save("Anna", to: defaults)
      LastNickname.save("Annie", to: defaults)
      XCTAssertEqual(LastNickname.load(from: defaults), "Annie")
    }
  }

  func testClearForgetsTheNickname() throws {
    try withTemporaryDefaults { defaults in
      LastNickname.save("Anna", to: defaults)
      LastNickname.clear(from: defaults)
      XCTAssertEqual(LastNickname.load(from: defaults), "")
    }
  }

  func testAnEmptyFieldIsFilledWithTheSavedNickname() {
    XCTAssertEqual(LastNickname.prefill(current: "", saved: "Anna"), "Anna")
    XCTAssertEqual(LastNickname.prefill(current: "  ", saved: "Anna"), "Anna")
  }

  func testWhatTheUserTypedIsKept() {
    XCTAssertEqual(LastNickname.prefill(current: "Ben", saved: "Anna"), "Ben")
  }

  func testNothingSavedLeavesTheFieldEmpty() {
    XCTAssertEqual(LastNickname.prefill(current: "", saved: ""), "")
  }
}
