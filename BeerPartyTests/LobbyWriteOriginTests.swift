import XCTest
@testable import BeerParty

@MainActor
final class LobbyWriteOriginTests: XCTestCase {

  func testOnlyTheUsersOwnActionsReportAFailure() {
    XCTAssertTrue(LobbyWriteOrigin.userAction.reportsFailure)
    XCTAssertFalse(LobbyWriteOrigin.timer.reportsFailure)
    XCTAssertFalse(LobbyWriteOrigin.automatic.reportsFailure)
  }

  // After adding a drink the write is forced; the five-minute timer's is not.
  func testAForcedBACWriteIsTheUsersAndTheTimedOneIsNot() {
    XCTAssertEqual(LobbyWriteOrigin.ofBACWrite(forced: true), .userAction)
    XCTAssertEqual(LobbyWriteOrigin.ofBACWrite(forced: false), .timer)
    XCTAssertTrue(LobbyWriteOrigin.ofBACWrite(forced: true).reportsFailure)
    XCTAssertFalse(LobbyWriteOrigin.ofBACWrite(forced: false).reportsFailure)
  }

  func testTheFirstUploadAfterSwitchingSharingOnIsTheUsers() {
    XCTAssertEqual(
      LobbyWriteOrigin.ofLocationUpload(sharingJustSwitchedOn: true, isResend: false),
      .userAction
    )
    // Whichever upload comes first after the switch, also the timed one.
    XCTAssertEqual(
      LobbyWriteOrigin.ofLocationUpload(sharingJustSwitchedOn: true, isResend: true),
      .userAction
    )
  }

  // Walking without signal: every new position fails, none is reported.
  func testLaterPositionsAndResendsStaySilent() {
    let newPosition = LobbyWriteOrigin.ofLocationUpload(sharingJustSwitchedOn: false, isResend: false)
    let resend = LobbyWriteOrigin.ofLocationUpload(sharingJustSwitchedOn: false, isResend: true)

    XCTAssertEqual(newPosition, .automatic)
    XCTAssertEqual(resend, .timer)
    XCTAssertFalse(newPosition.reportsFailure)
    XCTAssertFalse(resend.reportsFailure)
  }
}
