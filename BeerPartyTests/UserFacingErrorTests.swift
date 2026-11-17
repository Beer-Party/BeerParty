import XCTest
@testable import BeerParty

@MainActor
final class UserFacingErrorTests: XCTestCase {

  func testOfflineErrorsTellTheUserToCheckTheConnection() {
    for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed] {
      XCTAssertEqual(
        UserFacingError.message(couldNot: "add the drink", error: URLError(code)),
        "Couldn't add the drink. You seem to be offline. Check your connection and try again."
      )
    }
  }

  func testTimeoutAndUnreachableServerHaveTheirOwnAdvice() {
    XCTAssertEqual(
      UserFacingError.message(couldNot: "load the lobby", error: URLError(.timedOut)),
      "Couldn't load the lobby. The server took too long to answer. Please try again."
    )
    XCTAssertEqual(
      UserFacingError.message(couldNot: "load the lobby", error: URLError(.cannotConnectToHost)),
      "Couldn't load the lobby. The server can't be reached right now. Try again in a moment."
    )
  }

  // The same error arriving as an NSError, the way URLSession often delivers it.
  func testNSErrorFromTheURLDomainIsRecognised() {
    let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
    XCTAssertEqual(UserFacingError.advice(for: error), UserFacingError.offline)
  }

  func testUnknownErrorsNeverShowTheirRawDescription() {
    let raw = NSError(
      domain: "PostgrestError",
      code: 42501,
      userInfo: [NSLocalizedDescriptionKey: "new row violates row-level security policy"]
    )
    let message = UserFacingError.message(couldNot: "save your profile", error: raw)

    XCTAssertEqual(message, "Couldn't save your profile. Please try again.")
    XCTAssertFalse(message.contains("row-level"))
  }

  // The app's own errors are already written for the user and are shown unchanged.
  func testTheAppsOwnErrorsKeepTheirWording() {
    XCTAssertEqual(
      UserFacingError.message(couldNot: "close the lobby", error: LobbyLifecycleError.notCreator),
      "Only the lobby creator can perform this action."
    )
    XCTAssertEqual(
      UserFacingError.message(couldNot: "join the lobby", error: LobbyJoinError.noActiveLobbyForInviteCode),
      "No active lobby found for that invite code."
    )
    XCTAssertEqual(
      UserFacingError.message(couldNot: "update the drink", error: DrinkMutationError.editWindowExpired),
      "Drinks can only be edited or deleted within 15 minutes of being added."
    )
    XCTAssertEqual(
      UserFacingError.message(couldNot: "upload your profile photo", error: ProfileImageError.imageTooLarge),
      "Image is too large. Please pick a smaller photo."
    )
  }
}
