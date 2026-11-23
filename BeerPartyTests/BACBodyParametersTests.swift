import XCTest
@testable import BeerParty

@MainActor
final class BACBodyParametersTests: XCTestCase {

  private let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

  private func profile(weightPounds: Double, age: Int, gender: String) -> BACProfileFields {
    BACProfileFields(id: userID, weight: weightPounds, age: age, gender: gender)
  }

  // The bug this type exists for: the query returns only these four columns,
  // and the answer has to decode.
  func testDecodesExactlyWhatTheQueryReturns() throws {
    let json = """
      {"id":"11111111-2222-3333-4444-555555555555","weight":176.4,"age":27,"gender":"Male"}
      """
    let decoded = try JSONDecoder().decode(BACProfileFields.self, from: Data(json.utf8))
    XCTAssertEqual(decoded, profile(weightPounds: 176.4, age: 27, gender: "Male"))
  }

  func testAWholeNumberWeightDecodesToo() throws {
    let json = """
      {"id":"11111111-2222-3333-4444-555555555555","weight":180,"age":30,"gender":"female"}
      """
    let decoded = try JSONDecoder().decode(BACProfileFields.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.weight, 180)
  }

  func testAManGetsTheMaleFormula() {
    // 220.462 lb is 100 kg.
    let params = BACBodyParameters.derive(from: profile(weightPounds: 220.462, age: 30, gender: "Male"))
    XCTAssertEqual(params.userId, userID)
    XCTAssertEqual(params.tbw, 20.03 - 0.1183 * 30 + 0.3626 * 100, accuracy: 0.001)
    XCTAssertEqual(params.eliminationPerHourPromille, 0.13)
  }

  // "female" contains "male": it must not be read as male.
  func testAWomanGetsTheFemaleFormula() {
    // 132.2772 lb is 60 kg.
    let params = BACBodyParameters.derive(from: profile(weightPounds: 132.2772, age: 30, gender: "Female"))
    XCTAssertEqual(params.tbw, 14.46 + 0.2549 * 60, accuracy: 0.001)
    XCTAssertEqual(params.eliminationPerHourPromille, 0.15)
  }

  func testAnotherGenderGetsTheMiddleFormula() {
    let params = BACBodyParameters.derive(from: profile(weightPounds: 176.3696, age: 30, gender: "Other"))
    XCTAssertEqual(params.tbw, 17.25 + 0.308 * 80, accuracy: 0.001)
    XCTAssertEqual(params.eliminationPerHourPromille, 0.14)
  }

  func testDifferentBodiesGetDifferentValues() {
    let woman = BACBodyParameters.derive(from: profile(weightPounds: 132.2772, age: 25, gender: "female"))
    let man = BACBodyParameters.derive(from: profile(weightPounds: 220.462, age: 25, gender: "male"))
    XCTAssertLessThan(woman.tbw, man.tbw)
    XCTAssertNotEqual(woman.tbw, BACBodyParameters.fallbackTBW)
    XCTAssertNotEqual(man.tbw, BACBodyParameters.fallbackTBW)
  }

  func testVeryLowWeightAndAgeAreClamped() {
    let params = BACBodyParameters.derive(from: profile(weightPounds: 10, age: 3, gender: "male"))
    XCTAssertEqual(params.tbw, 20.03 - 0.1183 * 18 + 0.3626 * 40, accuracy: 0.001)
  }

  func testFallbackValues() {
    let params = BACBodyParameters.fallback(userID: userID)
    XCTAssertEqual(params, LobbyBACParamsData(userId: userID, tbw: 40, eliminationPerHourPromille: 0.14))
  }

  func testNoSavedRowNeedsSaving() {
    let derived = BACBodyParameters.fallback(userID: userID)
    XCTAssertTrue(BACBodyParameters.needsSaving(
      savedTBW: nil, savedEliminationPerHourPromille: nil, derived: derived))
    XCTAssertTrue(BACBodyParameters.needsSaving(
      savedTBW: 40, savedEliminationPerHourPromille: nil, derived: derived))
  }

  func testTheSameValuesAreNotSavedAgain() {
    let derived = BACBodyParameters.derive(from: profile(weightPounds: 220.462, age: 30, gender: "male"))
    XCTAssertFalse(BACBodyParameters.needsSaving(
      savedTBW: derived.tbw + 0.0000001,
      savedEliminationPerHourPromille: derived.eliminationPerHourPromille,
      derived: derived))
  }

  // What every member has saved today: the fallback is replaced.
  func testASavedFallbackIsReplacedByTheProfileValues() {
    let derived = BACBodyParameters.derive(from: profile(weightPounds: 220.462, age: 30, gender: "male"))
    XCTAssertTrue(BACBodyParameters.needsSaving(
      savedTBW: BACBodyParameters.fallbackTBW,
      savedEliminationPerHourPromille: BACBodyParameters.fallbackEliminationPerHourPromille,
      derived: derived))
  }

  func testAChangedEliminationRateAloneNeedsSaving() {
    let derived = LobbyBACParamsData(userId: userID, tbw: 40, eliminationPerHourPromille: 0.15)
    XCTAssertTrue(BACBodyParameters.needsSaving(
      savedTBW: 40, savedEliminationPerHourPromille: 0.14, derived: derived))
  }
}
