import AuthenticationServices
import XCTest
@testable import BeerParty

@MainActor
final class AppleSignInTests: XCTestCase {

  // Known SHA-256 values (FIPS 180-2 test vectors).
  func testSha256OfKnownTexts() {
    XCTAssertEqual(
      AppleSignIn.sha256("abc"),
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    )
    XCTAssertEqual(
      AppleSignIn.sha256(""),
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    )
  }

  func testNonceHasTheAskedLength() {
    XCTAssertEqual(AppleSignIn.randomNonce().count, 32)
    XCTAssertEqual(AppleSignIn.randomNonce(length: 48).count, 48)
    XCTAssertEqual(AppleSignIn.randomNonce(length: 0), "")
    XCTAssertEqual(AppleSignIn.randomNonce(length: -3), "")
  }

  func testNonceUsesOnlyCharactersThatNeedNoEscaping() {
    let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
    let nonce = AppleSignIn.randomNonce(length: 500)
    XCTAssertTrue(nonce.allSatisfy { allowed.contains($0) })
  }

  func testEachAttemptGetsItsOwnNonce() {
    XCTAssertNotEqual(AppleSignIn.randomNonce(), AppleSignIn.randomNonce())
  }

  func testClosingTheSheetIsNotAFailure() {
    XCTAssertTrue(AppleSignIn.isCancellation(ASAuthorizationError(.canceled)))
    XCTAssertFalse(AppleSignIn.isCancellation(ASAuthorizationError(.failed)))
    XCTAssertFalse(AppleSignIn.isCancellation(URLError(.notConnectedToInternet)))
  }

  func testIdentityTokenIsReadAsText() {
    XCTAssertEqual(AppleSignIn.identityToken(from: Data("header.payload.signature".utf8)), "header.payload.signature")
    XCTAssertNil(AppleSignIn.identityToken(from: nil))
    XCTAssertNil(AppleSignIn.identityToken(from: Data()))
    XCTAssertNil(AppleSignIn.identityToken(from: Data([0xFF, 0xFE])))
  }
}
