import XCTest
@testable import BeerParty

@MainActor
final class LockScreenTokenRefreshTests: XCTestCase {

  // After the hourly refresh the saved token is stale and must be replaced.
  func testNewTokenReplacesStoredToken() {
    XCTAssertEqual(LockScreenTokenRefresh.replacement(stored: "old", fresh: "new"), "new")
    XCTAssertEqual(LockScreenTokenRefresh.replacement(stored: nil, fresh: "new"), "new")
  }

  // The 30-second timer usually sees the same token: nothing to write.
  func testSameTokenIsNotWrittenAgain() {
    XCTAssertNil(LockScreenTokenRefresh.replacement(stored: "same", fresh: "same"))
  }

  // A failed session lookup must not wipe a token that may still work.
  func testMissingTokenKeepsStoredToken() {
    XCTAssertNil(LockScreenTokenRefresh.replacement(stored: "old", fresh: nil))
    XCTAssertNil(LockScreenTokenRefresh.replacement(stored: "old", fresh: ""))
  }
}
