import XCTest
@testable import BeerParty

@MainActor
final class LocationResendTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  private func isDue(
    sharing: Bool = true,
    hasLocation: Bool = true,
    secondsSinceUpload: TimeInterval?
  ) -> Bool {
    LocationResend.isDue(
      isSharing: sharing,
      hasLocation: hasLocation,
      lastUploadAt: secondsSinceUpload.map { now.addingTimeInterval(-$0) },
      now: now
    )
  }

  func testARecentUploadIsNotSentAgain() {
    XCTAssertFalse(isDue(secondsSinceUpload: 0))
    XCTAssertFalse(isDue(secondsSinceUpload: 20))
    XCTAssertFalse(isDue(secondsSinceUpload: 119))
  }

  // The bug: someone sitting in the bar was never uploaded again and left the
  // map after five minutes.
  func testAnUploadOlderThanTwoMinutesIsSentAgain() {
    XCTAssertTrue(isDue(secondsSinceUpload: 120))
    XCTAssertTrue(isDue(secondsSinceUpload: 121))
    XCTAssertTrue(isDue(secondsSinceUpload: 3600))
  }

  func testTheIntervalStaysWellUnderTheMapsFiveMinutes() {
    XCTAssertLessThanOrEqual(LocationResend.interval * 2, 5 * 60)
  }

  // A known position that was never saved (the first upload failed) is sent.
  func testAPositionThatWasNeverUploadedIsSent() {
    XCTAssertTrue(isDue(secondsSinceUpload: nil))
  }

  func testNothingIsSentWhenSharingIsOff() {
    XCTAssertFalse(isDue(sharing: false, secondsSinceUpload: 3600))
    XCTAssertFalse(isDue(sharing: false, secondsSinceUpload: nil))
  }

  func testNothingIsSentWithoutAKnownPosition() {
    XCTAssertFalse(isDue(hasLocation: false, secondsSinceUpload: 3600))
    XCTAssertFalse(isDue(hasLocation: false, secondsSinceUpload: nil))
  }

  // A phone whose clock jumped back does not send on every tick.
  func testAnUploadTimeInTheFutureIsNotDue() {
    XCTAssertFalse(isDue(secondsSinceUpload: -300))
  }
}
