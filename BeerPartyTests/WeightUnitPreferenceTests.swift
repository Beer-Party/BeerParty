import XCTest
@testable import BeerParty

@MainActor
final class WeightUnitPreferenceTests: XCTestCase {

  func testMetricRegionsStartInKilograms() {
    XCTAssertTrue(WeightUnitPreference.prefersKilograms(.metric))
    XCTAssertTrue(WeightUnitPreference.prefersKilograms(Locale(identifier: "de_DE").measurementSystem))
    XCTAssertTrue(WeightUnitPreference.prefersKilograms(Locale(identifier: "nb_NO").measurementSystem))
  }

  func testTheUSAndTheUKStartInPounds() {
    XCTAssertFalse(WeightUnitPreference.prefersKilograms(.us))
    XCTAssertFalse(WeightUnitPreference.prefersKilograms(.uk))
    XCTAssertFalse(WeightUnitPreference.prefersKilograms(Locale(identifier: "en_US").measurementSystem))
  }

  func testASavedWeightIsShownInWholePounds() {
    XCTAssertEqual(WeightUnitPreference.displayText(pounds: 165.3465, inKilograms: false), "165")
  }

  // The database holds pounds. 165.3465 lbs is the 75 kg a user typed.
  func testASavedWeightIsConvertedToKilograms() {
    XCTAssertEqual(WeightUnitPreference.displayText(pounds: 165.3465, inKilograms: true), "75.0")
    XCTAssertEqual(WeightUnitPreference.displayText(pounds: 180, inKilograms: true), "81.6")
  }

  // What is shown must read back as the weight that was saved.
  func testKilogramsShownReadBackAsTheSameWeight() throws {
    let saved = 75 * WeightUnitPreference.poundsPerKilogram
    let shown = WeightUnitPreference.displayText(pounds: saved, inKilograms: true)
    let typed = try XCTUnwrap(DecimalInput.parse(shown))
    XCTAssertEqual(typed * WeightUnitPreference.poundsPerKilogram, saved, accuracy: 0.2)
  }
}
