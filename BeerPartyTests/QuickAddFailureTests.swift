import XCTest
@testable import BeerParty

@MainActor
final class QuickAddFailureTests: XCTestCase {

  func testAnExpiredSignInIsTheOnlyStatusWithItsOwnAdvice() {
    XCTAssertEqual(QuickAddFailure.from(statusCode: 401), .signInExpired)
    XCTAssertEqual(QuickAddFailure.from(statusCode: 403), .other)
    XCTAssertEqual(QuickAddFailure.from(statusCode: 409), .other)
    XCTAssertEqual(QuickAddFailure.from(statusCode: 500), .other)
  }

  func testConnectionErrorsAreOffline() {
    XCTAssertEqual(QuickAddFailure.from(error: URLError(.notConnectedToInternet)), .offline)
    XCTAssertEqual(QuickAddFailure.from(error: URLError(.networkConnectionLost)), .offline)
    XCTAssertEqual(QuickAddFailure.from(error: URLError(.timedOut)), .offline)
    XCTAssertEqual(QuickAddFailure.from(error: URLError(.cannotFindHost)), .offline)
  }

  func testOtherErrorsAreOther() {
    XCTAssertEqual(QuickAddFailure.from(error: URLError(.badURL)), .other)
    XCTAssertEqual(QuickAddFailure.from(error: CocoaError(.coderInvalidValue)), .other)
  }

  // The intent throws a QuickAddFailure for a bad status; it must come back unchanged.
  func testAFailureThatIsAlreadyClassifiedIsKept() {
    XCTAssertEqual(QuickAddFailure.from(error: QuickAddFailure.signInExpired), .signInExpired)
    XCTAssertEqual(QuickAddFailure.from(error: QuickAddFailure.offline), .offline)
  }

  func testMessagesSayWhatFailedAndWhatToDo() {
    XCTAssertEqual(
      QuickAddFailure.signInExpired.message(couldNot: "add the drink"),
      "Couldn't add the drink. Open BeerParty, then try again."
    )
    XCTAssertEqual(
      QuickAddFailure.offline.message(couldNot: "send your vote"),
      "Couldn't send your vote. You seem to be offline."
    )
    XCTAssertEqual(
      QuickAddFailure.other.message(couldNot: "add the drink"),
      "Couldn't add the drink. Please try again."
    )
  }

  func testNoMessageShowsDeveloperOrServerText() {
    let failures: [QuickAddFailure] = [.signInExpired, .offline, .other]
    let texts = failures.map { $0.message(couldNot: "add the drink") } + [QuickAddFailure.noLobbyMessage]
    for text in texts {
      XCTAssertFalse(text.contains("Supabase"), text)
      XCTAssertFalse(text.contains("App Group"), text)
      XCTAssertFalse(text.contains("401"), text)
    }
  }
}
