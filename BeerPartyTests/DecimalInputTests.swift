import XCTest
@testable import BeerParty

@MainActor
final class DecimalInputTests: XCTestCase {

  func testPointAndCommaGiveTheSameNumber() {
    XCTAssertEqual(DecimalInput.parse("4.7"), 4.7)
    XCTAssertEqual(DecimalInput.parse("4,7"), 4.7)
  }

  func testWholeNumbers() {
    XCTAssertEqual(DecimalInput.parse("330"), 330)
    XCTAssertEqual(DecimalInput.parse("0"), 0)
  }

  func testLeadingOrTrailingSeparator() {
    XCTAssertEqual(DecimalInput.parse(",5"), 0.5)
    XCTAssertEqual(DecimalInput.parse("5,"), 5)
    XCTAssertEqual(DecimalInput.parse(".5"), 0.5)
  }

  func testSurroundingSpacesAreIgnored() {
    XCTAssertEqual(DecimalInput.parse(" 12,5 "), 12.5)
  }

  func testEmptyOrSeparatorOnlyIsRejected() {
    XCTAssertNil(DecimalInput.parse(""))
    XCTAssertNil(DecimalInput.parse("   "))
    XCTAssertNil(DecimalInput.parse(","))
    XCTAssertNil(DecimalInput.parse("."))
  }

  func testMoreThanOneSeparatorIsRejected() {
    XCTAssertNil(DecimalInput.parse("1,234.5"))
    XCTAssertNil(DecimalInput.parse("1.2.3"))
    XCTAssertNil(DecimalInput.parse("4,,7"))
  }

  func testAnythingButDigitsIsRejected() {
    XCTAssertNil(DecimalInput.parse("abc"))
    XCTAssertNil(DecimalInput.parse("-5"))
    XCTAssertNil(DecimalInput.parse("1e3"))
    XCTAssertNil(DecimalInput.parse("inf"))
    XCTAssertNil(DecimalInput.parse("nan"))
    XCTAssertNil(DecimalInput.parse("4 7"))
  }
}
