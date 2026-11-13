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
}
