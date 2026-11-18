import XCTest
@testable import BeerParty

@MainActor
final class DrinkInputLimitsTests: XCTestCase {

  func testOrdinaryDrinksAreAllowed() {
    XCTAssertNil(DrinkInputLimits.message(volumeMl: 330, abv: 5))
    XCTAssertNil(DrinkInputLimits.message(volumeMl: 44, abv: 40))
    XCTAssertNil(DrinkInputLimits.message(volumeMl: 250, abv: 0))
    XCTAssertTrue(DrinkInputLimits.allows(volumeMl: 500, abv: 4.7))
  }

  func testTheLimitsThemselvesAreAllowed() {
    XCTAssertNil(DrinkInputLimits.message(volumeMl: 2000, abv: 100))
    XCTAssertTrue(DrinkInputLimits.allows(volumeMl: 2000, abv: 100))
  }

  func testAbvAbove100IsRejected() {
    XCTAssertEqual(DrinkInputLimits.message(volumeMl: 330, abv: 400), DrinkInputLimits.abvMessage)
    XCTAssertEqual(DrinkInputLimits.message(volumeMl: 330, abv: 100.1), DrinkInputLimits.abvMessage)
    XCTAssertFalse(DrinkInputLimits.allows(volumeMl: 330, abv: 400))
  }

  func testVolumeAboveTwoLitresIsRejected() {
    XCTAssertEqual(DrinkInputLimits.message(volumeMl: 33000, abv: 5), DrinkInputLimits.volumeMessage)
    XCTAssertEqual(DrinkInputLimits.message(volumeMl: 2001, abv: 5), DrinkInputLimits.volumeMessage)
    XCTAssertFalse(DrinkInputLimits.allows(volumeMl: 33000, abv: 5))
  }

  func testBothProblemsAreNamed() {
    XCTAssertEqual(
      DrinkInputLimits.message(volumeMl: 33000, abv: 400),
      "Volume can be at most 2000 ml. ABV can be at most 100 %."
    )
  }

  func testMissingValuesAreNotJudged() {
    XCTAssertNil(DrinkInputLimits.message(volumeMl: nil, abv: nil))
    XCTAssertNil(DrinkInputLimits.message(volumeMl: nil, abv: 5))
    XCTAssertEqual(DrinkInputLimits.message(volumeMl: nil, abv: 400), DrinkInputLimits.abvMessage)
    XCTAssertEqual(DrinkInputLimits.message(volumeMl: 33000, abv: nil), DrinkInputLimits.volumeMessage)
  }

  func testTheServiceErrorCarriesTheSameSentence() {
    XCTAssertEqual(
      UserFacingError.message(couldNot: "add the drink", error: DrinkMutationError.outOfRange),
      "Volume can be at most 2000 ml. ABV can be at most 100 %."
    )
  }
}
