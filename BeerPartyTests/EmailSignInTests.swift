import XCTest
@testable import BeerParty

@MainActor
final class EmailSignInTests: XCTestCase {

  func testCleanedEmailDropsSurroundingSpace() {
    XCTAssertEqual(EmailSignIn.cleanedEmail("  anna@example.com \n"), "anna@example.com")
    XCTAssertEqual(EmailSignIn.cleanedEmail("anna@example.com"), "anna@example.com")
    XCTAssertEqual(EmailSignIn.cleanedEmail("   "), "")
  }

  func testPlausibleAddresses() {
    XCTAssertTrue(EmailSignIn.isPlausibleEmail("anna@example.com"))
    XCTAssertTrue(EmailSignIn.isPlausibleEmail("  anna@example.com  "))
    XCTAssertTrue(EmailSignIn.isPlausibleEmail("anna.b+beer@mail.example.co.uk"))
    XCTAssertTrue(EmailSignIn.isPlausibleEmail("a@b.c"))
  }

  func testImplausibleAddresses() {
    XCTAssertFalse(EmailSignIn.isPlausibleEmail(""))
    XCTAssertFalse(EmailSignIn.isPlausibleEmail("anna"))
    XCTAssertFalse(EmailSignIn.isPlausibleEmail("anna@"))
    XCTAssertFalse(EmailSignIn.isPlausibleEmail("@example.com"))
    XCTAssertFalse(EmailSignIn.isPlausibleEmail("anna@example"))
    XCTAssertFalse(EmailSignIn.isPlausibleEmail("anna@example."))
    XCTAssertFalse(EmailSignIn.isPlausibleEmail("anna@.com"))
    XCTAssertFalse(EmailSignIn.isPlausibleEmail("anna@example..com"))
    XCTAssertFalse(EmailSignIn.isPlausibleEmail("anna@@example.com"))
    XCTAssertFalse(EmailSignIn.isPlausibleEmail("anna b@example.com"))
    XCTAssertFalse(EmailSignIn.isPlausibleEmail(String(repeating: "a", count: 250) + "@b.co"))
  }

  func testCleanedCodeKeepsOnlyDigits() {
    XCTAssertEqual(EmailSignIn.cleanedCode("123456"), "123456")
    XCTAssertEqual(EmailSignIn.cleanedCode(" 123 456 "), "123456")
    XCTAssertEqual(EmailSignIn.cleanedCode("123-456"), "123456")
    XCTAssertEqual(EmailSignIn.cleanedCode("code: 12ab34"), "1234")
    XCTAssertEqual(EmailSignIn.cleanedCode(""), "")
  }

  func testCleanedCodeDropsDigitsOfOtherScripts() {
    // Arabic-Indic digits count as numbers but are not what the mail shows.
    XCTAssertEqual(EmailSignIn.cleanedCode("١٢٣456"), "456")
  }

  func testCleanedCodeIsCutToTheLongestCode() {
    XCTAssertEqual(EmailSignIn.cleanedCode("1234567890123"), "1234567890")
  }

  func testCodeIsCompleteFromSixDigits() {
    XCTAssertFalse(EmailSignIn.isCompleteCode(""))
    XCTAssertFalse(EmailSignIn.isCompleteCode("12345"))
    XCTAssertFalse(EmailSignIn.isCompleteCode("12 34 5"))
    XCTAssertTrue(EmailSignIn.isCompleteCode("123456"))
    XCTAssertTrue(EmailSignIn.isCompleteCode("123 456"))
    XCTAssertTrue(EmailSignIn.isCompleteCode("12345678"))
    XCTAssertTrue(EmailSignIn.isCompleteCode("1234567890"))
  }

  func testResendWait() {
    let sentAt = Date(timeIntervalSince1970: 1_800_000_000)
    XCTAssertEqual(EmailSignIn.secondsUntilResend(lastSentAt: nil, now: sentAt), 0)
    XCTAssertEqual(EmailSignIn.secondsUntilResend(lastSentAt: sentAt, now: sentAt), 60)
    XCTAssertEqual(
      EmailSignIn.secondsUntilResend(lastSentAt: sentAt, now: sentAt.addingTimeInterval(15.5)),
      45
    )
    XCTAssertEqual(
      EmailSignIn.secondsUntilResend(lastSentAt: sentAt, now: sentAt.addingTimeInterval(59.5)),
      1
    )
    XCTAssertEqual(
      EmailSignIn.secondsUntilResend(lastSentAt: sentAt, now: sentAt.addingTimeInterval(60)),
      0
    )
    XCTAssertEqual(
      EmailSignIn.secondsUntilResend(lastSentAt: sentAt, now: sentAt.addingTimeInterval(600)),
      0
    )
  }

  func testResendWaitWithAClockSetBack() {
    // The phone's clock was moved back after the code was sent: never wait
    // longer than the full minute.
    let sentAt = Date(timeIntervalSince1970: 1_800_000_000)
    XCTAssertEqual(
      EmailSignIn.secondsUntilResend(lastSentAt: sentAt, now: sentAt.addingTimeInterval(-3600)),
      60
    )
  }
}
