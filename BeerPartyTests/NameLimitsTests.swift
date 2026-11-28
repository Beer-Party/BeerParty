import XCTest
@testable import BeerParty

@MainActor
final class NameLimitsTests: XCTestCase {

  func testTheLimits() {
    XCTAssertEqual(NameLimits.Kind.nickname.maxLength, 24)
    XCTAssertEqual(NameLimits.Kind.lobbyName.maxLength, 40)
    XCTAssertEqual(NameLimits.Kind.drinkName.maxLength, 40)
    XCTAssertEqual(NameLimits.Kind.motionDestination.maxLength, 60)
  }

  func testNicknameStaysBelowWhatTheDatabaseRefuses() {
    // lobby_members_nickname_check: length(nickname) < 30.
    XCTAssertLessThan(NameLimits.Kind.nickname.maxLength, 30)
  }

  func testOrdinaryNamesAreAllowed() {
    XCTAssertNil(NameLimits.message(for: "Lev", kind: .nickname))
    XCTAssertNil(NameLimits.message(for: "Friday at the harbour", kind: .lobbyName))
    XCTAssertNil(NameLimits.message(for: "Beer", kind: .drinkName))
    XCTAssertNil(NameLimits.message(for: "the kebab place", kind: .motionDestination))
  }

  func testEmptyTextIsNotJudged() {
    for kind in NameLimits.Kind.allCases {
      XCTAssertNil(NameLimits.message(for: "", kind: kind))
      XCTAssertNil(NameLimits.message(for: "   ", kind: kind))
    }
  }

  func testTheLimitItselfIsAllowedAndOneMoreIsNot() {
    for kind in NameLimits.Kind.allCases {
      let atLimit = String(repeating: "a", count: kind.maxLength)
      XCTAssertTrue(NameLimits.allows(atLimit, kind: kind))
      XCTAssertFalse(NameLimits.allows(atLimit + "a", kind: kind))
    }
  }

  func testLengthIsCountedAfterTrimming() {
    let atLimit = String(repeating: "a", count: 24)
    XCTAssertTrue(NameLimits.allows("   \(atLimit) \n", kind: .nickname))
    XCTAssertEqual(NameLimits.trimmed("  Lev \n"), "Lev")
  }

  func testSpacesInsideTheNameCount() {
    let name = String(repeating: "a", count: 12) + " " + String(repeating: "b", count: 12)
    XCTAssertFalse(NameLimits.allows(name, kind: .nickname))
  }

  func testAnEmojiCountsAsOneCharacter() {
    let beers = String(repeating: "🍺", count: 24)
    XCTAssertTrue(NameLimits.allows(beers, kind: .nickname))
    XCTAssertFalse(NameLimits.allows(beers + "🍺", kind: .nickname))
    // A flag is several code points but one character on screen.
    XCTAssertTrue(NameLimits.allows(String(repeating: "🏴‍☠️", count: 24), kind: .nickname))
  }

  func testTheMessageNamesTheFieldTheLimitAndTheLength() {
    let long = String(repeating: "a", count: 31)
    XCTAssertEqual(
      NameLimits.message(for: long, kind: .nickname),
      "Nickname can be at most 24 characters (now 31)."
    )
    XCTAssertEqual(
      NameLimits.message(for: String(repeating: "a", count: 61), kind: .motionDestination),
      "Destination can be at most 60 characters (now 61)."
    )
  }

  func testCheckThrowsForATooLongName() {
    XCTAssertNoThrow(try NameLimits.check("Beer", kind: .drinkName))
    XCTAssertThrowsError(try NameLimits.check(String(repeating: "a", count: 41), kind: .drinkName)) { error in
      XCTAssertEqual(error as? NameLimitError, NameLimitError(kind: .drinkName))
    }
  }

  func testTheErrorIsShownToTheUserAsItIs() {
    let error = NameLimitError(kind: .lobbyName)
    XCTAssertEqual(error.errorDescription, "Lobby name can be at most 40 characters.")
    XCTAssertEqual(
      UserFacingError.message(couldNot: "create the lobby", error: error),
      "Lobby name can be at most 40 characters."
    )
  }

  func testADrinkDraftWithATooLongNameCannotBeSaved() {
    var draft = DrinkDraft(name: String(repeating: "a", count: 41), volumeText: "330", abvText: "5")
    XCTAssertFalse(draft.canSubmit)
    XCTAssertEqual(draft.limitMessage, "Drink name can be at most 40 characters (now 41).")

    draft.name = String(repeating: "a", count: 40)
    XCTAssertTrue(draft.canSubmit)
    XCTAssertNil(draft.limitMessage)
  }

  func testADrinkDraftListsNameAndNumberProblemsTogether() {
    let draft = DrinkDraft(name: String(repeating: "a", count: 41), volumeText: "330", abvText: "400")
    XCTAssertEqual(
      draft.limitMessage,
      "Drink name can be at most 40 characters (now 41). \(DrinkInputLimits.abvMessage)"
    )
  }
}
