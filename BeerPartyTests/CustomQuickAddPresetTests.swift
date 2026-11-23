import XCTest
@testable import BeerParty

@MainActor
final class CustomQuickAddPresetTests: XCTestCase {

  func testTheButtonCarriesTheDrinkAsTyped() {
    let preset = QuickAddDrinkPreset.custom(name: "Pale Ale", volumeMl: 500, abv: 4.7)
    XCTAssertEqual(
      preset,
      QuickAddDrinkPreset(id: "custom", name: "Pale Ale", volumeMl: 500, abv: 4.7)
    )
  }

  func testSpacesAroundTheNameAreRemoved() {
    XCTAssertEqual(QuickAddDrinkPreset.custom(name: "  Cider \n", volumeMl: 330, abv: 4.5)?.name, "Cider")
  }

  // The bug: the name was read after the form had been emptied.
  func testAnEmptyNameMakesNoButton() {
    XCTAssertNil(QuickAddDrinkPreset.custom(name: "", volumeMl: 330, abv: 5))
    XCTAssertNil(QuickAddDrinkPreset.custom(name: "   ", volumeMl: 330, abv: 5))
  }

  func testTheButtonAlwaysHasTheCustomID() {
    XCTAssertEqual(QuickAddDrinkPreset.custom(name: "Beer", volumeMl: 330, abv: 5)?.id, "custom")
    XCTAssertFalse(QuickAddDrinkPreset.defaults.contains { $0.id == "custom" })
  }
}
