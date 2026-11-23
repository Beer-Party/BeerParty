import XCTest
@testable import BeerParty

@MainActor
final class InviteCodeMatchTests: XCTestCase {

  func testAPlainCodeIsItsOwnPattern() {
    XCTAssertEqual(LobbyInvite.caseInsensitivePattern(for: "Beer2026"), "Beer2026")
    XCTAssertEqual(LobbyInvite.caseInsensitivePattern(for: ""), "")
  }

  // In a pattern "%" means "anything" and "_" means "any one character".
  func testPatternCharactersAreEscaped() {
    XCTAssertEqual(LobbyInvite.caseInsensitivePattern(for: "100%"), "100\\%")
    XCTAssertEqual(LobbyInvite.caseInsensitivePattern(for: "a_b"), "a\\_b")
    XCTAssertEqual(LobbyInvite.caseInsensitivePattern(for: "a\\b"), "a\\\\b")
    XCTAssertEqual(LobbyInvite.caseInsensitivePattern(for: "%_\\"), "\\%\\_\\\\")
  }

  func testOtherCharactersAreLeftAlone() {
    XCTAssertEqual(LobbyInvite.caseInsensitivePattern(for: "øl-fest!"), "øl-fest!")
  }

  func testCodesAreComparedWithoutRegardToCase() {
    XCTAssertTrue(LobbyInvite.isSameCode("beer", "Beer"))
    XCTAssertTrue(LobbyInvite.isSameCode("ØL", "øl"))
    XCTAssertFalse(LobbyInvite.isSameCode("beer", "beers"))
  }

  // The bug: a friend told "beer" who typed "Beer" found no lobby.
  func testACodeInDifferentCaseFindsTheLobby() {
    XCTAssertEqual(LobbyInvite.match(typed: "Beer", among: ["beer"]), .one(0))
    XCTAssertEqual(LobbyInvite.match(typed: "beer", among: ["BEER"]), .one(0))
  }

  func testNoLobbyIsFoundForAnotherCode() {
    XCTAssertEqual(LobbyInvite.match(typed: "beer", among: []), .none)
    // "*" in the pattern matches anything in the database; such rows are ignored.
    XCTAssertEqual(LobbyInvite.match(typed: "be*", among: ["beer", "bean"]), .none)
  }

  func testAWildcardCodeStillFindsItsOwnLobby() {
    XCTAssertEqual(LobbyInvite.match(typed: "be*", among: ["beer", "BE*"]), .one(1))
  }

  // Two old lobbies whose codes differ only in case can both still be joined
  // by typing the code exactly.
  func testAnExactSpellingWinsOverOtherCases() {
    XCTAssertEqual(LobbyInvite.match(typed: "Beer", among: ["beer", "Beer"]), .one(1))
    XCTAssertEqual(LobbyInvite.match(typed: "beer", among: ["beer", "Beer"]), .one(0))
  }

  func testSeveralLobbiesAndNoExactSpellingIsReported() {
    XCTAssertEqual(LobbyInvite.match(typed: "BEER", among: ["beer", "Beer"]), .several)
  }

  func testTwoLobbiesWithExactlyTheSameCodeAreReported() {
    XCTAssertEqual(LobbyInvite.match(typed: "beer", among: ["beer", "beer"]), .several)
  }
}
