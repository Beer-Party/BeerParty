import XCTest
@testable import BeerParty

@MainActor
final class ProfileStateTests: XCTestCase {

  // The hourly token refresh re-checks the profile. A confirmed profile must stay
  // .complete during that check, or RootView replaces the lobby with a spinner.
  func testConfirmedProfileStaysCompleteWhileRechecking() {
    XCTAssertEqual(ProfileState.whileChecking(current: .complete, alreadyVerified: true), .complete)
  }

  func testUnconfirmedProfileShowsSpinnerWhileChecking() {
    XCTAssertEqual(ProfileState.whileChecking(current: .unknown, alreadyVerified: false), .unknown)
    XCTAssertEqual(ProfileState.whileChecking(current: .needsProfile, alreadyVerified: false), .unknown)
    // .complete left over from a different user is not trusted.
    XCTAssertEqual(ProfileState.whileChecking(current: .complete, alreadyVerified: false), .unknown)
  }

  // B2: only "the request worked and there is no row" means a new user.
  func testMissingRowSendsUserToProfileSetup() {
    XCTAssertEqual(ProfileState.afterCheck(.missing, alreadyVerified: false), .needsProfile)
    XCTAssertEqual(ProfileState.afterCheck(.missing, alreadyVerified: true), .needsProfile)
  }

  func testFoundRowIsComplete() {
    XCTAssertEqual(ProfileState.afterCheck(.found, alreadyVerified: false), .complete)
    XCTAssertEqual(ProfileState.afterCheck(.found, alreadyVerified: true), .complete)
  }

  // Offline at launch used to land an existing user on profile setup.
  func testFailedCheckOffersRetryInsteadOfProfileSetup() {
    XCTAssertEqual(ProfileState.afterCheck(.failed, alreadyVerified: false), .checkFailed)
  }

  func testFailedRecheckKeepsConfirmedProfile() {
    XCTAssertEqual(ProfileState.afterCheck(.failed, alreadyVerified: true), .complete)
  }

  func testRetryAfterFailedCheckShowsSpinner() {
    XCTAssertEqual(ProfileState.whileChecking(current: .checkFailed, alreadyVerified: false), .unknown)
  }
}
