import XCTest
@testable import BeerParty

@MainActor
final class QuickAddPresetTests: XCTestCase {

  // The Lock Screen buttons now use these shared presets instead of their own copy.
  // These are the values the widget had hard-coded.
  func testSharedPresetsMatchTheLockScreenButtons() {
    XCTAssertEqual(QuickAddDrinkPreset.beer, QuickAddDrinkPreset(id: "beer", name: "Beer", volumeMl: 330, abv: 5))
    XCTAssertEqual(QuickAddDrinkPreset.wine, QuickAddDrinkPreset(id: "wine", name: "Wine", volumeMl: 150, abv: 12))
    XCTAssertEqual(QuickAddDrinkPreset.shot, QuickAddDrinkPreset(id: "shot", name: "Shot", volumeMl: 44, abv: 40))
    XCTAssertEqual(QuickAddDrinkPreset.water, QuickAddDrinkPreset(id: "water", name: "Water", volumeMl: 250, abv: 0))
    XCTAssertEqual(QuickAddDrinkPreset.defaults.map(\.id), ["beer", "wine", "shot", "water"])
  }
}
