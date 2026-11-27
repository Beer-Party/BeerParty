import XCTest
@testable import BeerParty

@MainActor
final class MadeItHomeSharingTests: XCTestCase {

  func testEndsSharingOnlyWhenSharingIsOn() {
    XCTAssertTrue(MadeItHomeSharing.endsSharing(wantsSharing: true, pausedAfterHome: false))
    XCTAssertFalse(MadeItHomeSharing.endsSharing(wantsSharing: false, pausedAfterHome: false))
  }

  func testSecondMadeItHomeHasNothingLeftToEnd() {
    XCTAssertFalse(MadeItHomeSharing.endsSharing(wantsSharing: true, pausedAfterHome: true))
  }

  func testConfirmationSaysWhenSharingEnded() {
    XCTAssertEqual(
      MadeItHomeSharing.confirmation(nickname: "Lev", endedSharing: true),
      "Lev is safely at the fortress of dreams. Your location is no longer shared."
    )
  }

  func testConfirmationIsUnchangedWhenNothingWasShared() {
    XCTAssertEqual(
      MadeItHomeSharing.confirmation(nickname: "Lev", endedSharing: false),
      "Lev is safely at the fortress of dreams."
    )
  }

  func testHintOnlyWhileTheToggleIsOnAndSharingIsPaused() {
    XCTAssertTrue(MadeItHomeSharing.showsPausedHint(wantsSharing: true, pausedAfterHome: true))
    XCTAssertFalse(MadeItHomeSharing.showsPausedHint(wantsSharing: true, pausedAfterHome: false))
    XCTAssertFalse(MadeItHomeSharing.showsPausedHint(wantsSharing: false, pausedAfterHome: true))
  }
}
