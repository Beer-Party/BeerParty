import XCTest
@testable import BeerParty

@MainActor
final class DrinkDraftTests: XCTestCase {

  private func drink(name: String, volumeMl: Double, abv: Double) -> LobbyDrink {
    LobbyDrink(
      id: UUID(),
      userId: UUID(),
      name: name,
      volumeMl: volumeMl,
      abv: abv,
      consumedAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
  }

  func testAnEmptyFormCannotBeSubmitted() {
    let draft = DrinkDraft()
    XCTAssertEqual(draft.trimmedName, "")
    XCTAssertNil(draft.volumeMl)
    XCTAssertNil(draft.abv)
    XCTAssertFalse(draft.isComplete)
    XCTAssertFalse(draft.canSubmit)
    XCTAssertNil(draft.limitMessage)
  }

  func testAFilledFormCanBeSubmitted() {
    let draft = DrinkDraft(name: "  Pale Ale ", volumeText: "500", abvText: "4.7")
    XCTAssertEqual(draft.trimmedName, "Pale Ale")
    XCTAssertEqual(draft.volumeMl, 500)
    XCTAssertEqual(draft.abv, 4.7)
    XCTAssertTrue(draft.isComplete)
    XCTAssertTrue(draft.canSubmit)
  }

  func testADecimalCommaIsAccepted() {
    let draft = DrinkDraft(name: "Pils", volumeText: "330", abvText: "4,7")
    XCTAssertEqual(draft.abv, 4.7)
    XCTAssertTrue(draft.canSubmit)
  }

  func testANameOfOnlySpacesIsNotAName() {
    let draft = DrinkDraft(name: "   ", volumeText: "330", abvText: "5")
    XCTAssertFalse(draft.isComplete)
    XCTAssertFalse(draft.canSubmit)
  }

  func testVolumeMustBeAboveZero() {
    XCTAssertNil(DrinkDraft(name: "Beer", volumeText: "0", abvText: "5").volumeMl)
    XCTAssertNil(DrinkDraft(name: "Beer", volumeText: "abc", abvText: "5").volumeMl)
    XCTAssertFalse(DrinkDraft(name: "Beer", volumeText: "0", abvText: "5").canSubmit)
  }

  func testAbvMayBeZero() {
    let water = DrinkDraft(name: "Water", volumeText: "250", abvText: "0")
    XCTAssertEqual(water.abv, 0)
    XCTAssertTrue(water.canSubmit)
  }

  func testValuesAboveTheLimitsBlockSubmitAndSayWhy() {
    let strong = DrinkDraft(name: "Slip", volumeText: "330", abvText: "400")
    XCTAssertTrue(strong.isComplete)
    XCTAssertEqual(strong.limitMessage, DrinkInputLimits.abvMessage)
    XCTAssertFalse(strong.canSubmit)

    let large = DrinkDraft(name: "Slip", volumeText: "33000", abvText: "5")
    XCTAssertEqual(large.limitMessage, DrinkInputLimits.volumeMessage)
    XCTAssertFalse(large.canSubmit)
  }

  func testEditingADrinkFillsInTheForm() {
    let draft = DrinkDraft(editing: drink(name: "Wine", volumeMl: 150, abv: 12))
    XCTAssertEqual(draft.name, "Wine")
    XCTAssertEqual(draft.volumeText, "150")
    XCTAssertEqual(draft.abvText, "12.0")
    XCTAssertEqual(draft.volumeMl, 150)
    XCTAssertEqual(draft.abv, 12)
    XCTAssertTrue(draft.canSubmit)
  }

  func testEditingKeepsOneDecimalOfAbv() {
    let draft = DrinkDraft(editing: drink(name: "Pils", volumeMl: 330, abv: 4.7))
    XCTAssertEqual(draft.abvText, "4.7")
    XCTAssertEqual(draft.abv, 4.7)
  }
}
