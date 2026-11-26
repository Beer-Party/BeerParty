import XCTest
@testable import BeerParty

@MainActor
final class ProfileInputLimitsTests: XCTestCase {

  func testOrdinaryWeightsAreAccepted() {
    XCTAssertNil(ProfileInputLimits.weightMessage(entered: 75, inKilograms: true))
    XCTAssertNil(ProfileInputLimits.weightMessage(entered: 165, inKilograms: false))
  }

  func testTheLimitsThemselvesAreAccepted() {
    XCTAssertNil(ProfileInputLimits.weightMessage(entered: 30, inKilograms: true))
    XCTAssertNil(ProfileInputLimits.weightMessage(entered: 300, inKilograms: true))
    XCTAssertNil(ProfileInputLimits.weightMessage(entered: 66, inKilograms: false))
    XCTAssertNil(ProfileInputLimits.weightMessage(entered: 661, inKilograms: false))
  }

  // 750 instead of 75: the slip the limit is for.
  func testASlipInKilogramsIsRejectedWithTheKilogramRange() {
    XCTAssertEqual(
      ProfileInputLimits.weightMessage(entered: 750, inKilograms: true),
      ProfileInputLimits.kilogramsMessage
    )
    XCTAssertEqual(
      ProfileInputLimits.weightMessage(entered: 7.5, inKilograms: true),
      ProfileInputLimits.kilogramsMessage
    )
    XCTAssertEqual(
      ProfileInputLimits.weightMessage(entered: 300.1, inKilograms: true),
      ProfileInputLimits.kilogramsMessage
    )
  }

  func testASlipInPoundsIsRejectedWithThePoundRange() {
    XCTAssertEqual(
      ProfileInputLimits.weightMessage(entered: 1650, inKilograms: false),
      ProfileInputLimits.poundsMessage
    )
    XCTAssertEqual(
      ProfileInputLimits.weightMessage(entered: 16, inKilograms: false),
      ProfileInputLimits.poundsMessage
    )
  }

  // 400 is fine as pounds and too much as kilograms.
  func testTheUnitShownDecides() {
    XCTAssertNil(ProfileInputLimits.weightMessage(entered: 400, inKilograms: false))
    XCTAssertNotNil(ProfileInputLimits.weightMessage(entered: 400, inKilograms: true))
    XCTAssertNil(ProfileInputLimits.weightMessage(entered: 40, inKilograms: true))
    XCTAssertNotNil(ProfileInputLimits.weightMessage(entered: 40, inKilograms: false))
  }

  // The two ranges describe the same weights.
  func testThePoundRangeMatchesTheKilogramRange() {
    let perKilogram = WeightUnitPreference.poundsPerKilogram
    XCTAssertEqual(ProfileInputLimits.minWeightLbs, ProfileInputLimits.minWeightKg * perKilogram, accuracy: 0.5)
    XCTAssertEqual(ProfileInputLimits.maxWeightLbs, ProfileInputLimits.maxWeightKg * perKilogram, accuracy: 0.5)
  }

  // Nothing typed yet, or zero: no message, the Save button is off anyway.
  func testAnEmptyOrZeroWeightGetsNoMessage() {
    XCTAssertNil(ProfileInputLimits.weightMessage(entered: nil, inKilograms: true))
    XCTAssertNil(ProfileInputLimits.weightMessage(entered: 0, inKilograms: true))
    XCTAssertNil(ProfileInputLimits.weightMessage(entered: -5, inKilograms: false))
  }

  func testAgesUpToTheLimitAreAccepted() {
    XCTAssertNil(ProfileInputLimits.ageMessage(age: 18))
    XCTAssertNil(ProfileInputLimits.ageMessage(age: 120))
    XCTAssertNil(ProfileInputLimits.ageMessage(age: nil))
    XCTAssertNil(ProfileInputLimits.ageMessage(age: 0))
  }

  func testAnAgeAboveTheLimitIsRejected() {
    XCTAssertEqual(ProfileInputLimits.ageMessage(age: 121), ProfileInputLimits.ageLimitMessage)
    XCTAssertEqual(ProfileInputLimits.ageMessage(age: 400), ProfileInputLimits.ageLimitMessage)
  }

  func testAllowsNeedsBothWithinTheLimits() {
    XCTAssertTrue(ProfileInputLimits.allows(enteredWeight: 75, inKilograms: true, age: 30))
    XCTAssertFalse(ProfileInputLimits.allows(enteredWeight: 750, inKilograms: true, age: 30))
    XCTAssertFalse(ProfileInputLimits.allows(enteredWeight: 75, inKilograms: true, age: 400))
  }
}
