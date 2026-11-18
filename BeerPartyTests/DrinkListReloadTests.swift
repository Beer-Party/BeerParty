import XCTest
@testable import BeerParty

@MainActor
final class DrinkListReloadTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_800_000_000)
  private let anna = UUID()
  private let ben = UUID()

  private func drink(
    id: UUID = UUID(),
    by userId: UUID,
    _ name: String = "Beer",
    abv: Double = 5,
    minute: Double
  ) -> LobbyDrink {
    LobbyDrink(
      id: id,
      userId: userId,
      name: name,
      volumeMl: 330,
      abv: abv,
      consumedAt: start.addingTimeInterval(minute * 60)
    )
  }

  func testNothingChangedLeavesTheScreenAlone() {
    let shown = [drink(by: anna, minute: 0), drink(by: ben, minute: 5)]
    XCTAssertNil(DrinkListReload.reloadedList(shownBefore: shown, shownNow: shown, fetched: shown))
    XCTAssertNil(DrinkListReload.reloadedList(shownBefore: shown, shownNow: shown, fetched: shown.reversed()))
    XCTAssertNil(DrinkListReload.reloadedList(shownBefore: [], shownNow: [], fetched: []))
  }

  func testAnotherMembersEditArrives() {
    let bensDrink = drink(by: ben, "Beer", abv: 5, minute: 5)
    let shown = [drink(by: anna, minute: 0), bensDrink]
    let edited = drink(id: bensDrink.id, by: ben, "Strong beer", abv: 9, minute: 5)

    let reloaded = DrinkListReload.reloadedList(
      shownBefore: shown,
      shownNow: shown,
      fetched: [shown[0], edited]
    )

    XCTAssertEqual(reloaded, [shown[0], edited])
  }

  func testAnotherMembersDeletionArrives() {
    let shown = [drink(by: anna, minute: 0), drink(by: ben, minute: 5)]

    let reloaded = DrinkListReload.reloadedList(
      shownBefore: shown,
      shownNow: shown,
      fetched: [shown[0]]
    )

    XCTAssertEqual(reloaded, [shown[0]])
  }

  func testDrinkFromAPhoneWithASlowClockArrivesInTimeOrder() {
    let shown = [drink(by: anna, minute: 0), drink(by: anna, minute: 30)]
    // Logged just now, but stamped 20 minutes ago by Ben's phone: older than the
    // newest drink shown, so the 30-second refresh never asks for it.
    let late = drink(by: ben, minute: 10)

    let reloaded = DrinkListReload.reloadedList(
      shownBefore: shown,
      shownNow: shown,
      fetched: [shown[0], shown[1], late]
    )

    XCTAssertEqual(reloaded, [shown[0], late, shown[1]])
  }

  func testAnswerIsDroppedWhenTheListChangedDuringTheRequest() {
    let before = [drink(by: anna, minute: 0)]
    // Anna added a drink while the request was in flight; the server's answer
    // does not contain it yet.
    let now = before + [drink(by: anna, minute: 1)]

    XCTAssertNil(DrinkListReload.reloadedList(shownBefore: before, shownNow: now, fetched: before))
  }

  func testAnswerIsDroppedWhenADrinkWasDeletedDuringTheRequest() {
    let before = [drink(by: anna, minute: 0), drink(by: anna, minute: 1)]
    let now = [before[0]]

    XCTAssertNil(DrinkListReload.reloadedList(shownBefore: before, shownNow: now, fetched: before))
  }

  func testDrinksNotShownSkipsDrinksAlreadyOnScreen() {
    let shown = [drink(by: anna, minute: 0), drink(by: ben, minute: 5)]
    let new = drink(by: ben, minute: 6)

    XCTAssertEqual(DrinkListReload.drinksNotShown([shown[1], new], shown: shown), [new])
    XCTAssertEqual(DrinkListReload.drinksNotShown([shown[0], shown[1]], shown: shown), [])
    XCTAssertEqual(DrinkListReload.drinksNotShown([new], shown: []), [new])
  }

  func testDrinksNotShownKeepsOneCopyOfARepeatedRow() {
    let new = drink(by: ben, minute: 6)
    XCTAssertEqual(DrinkListReload.drinksNotShown([new, new], shown: []), [new])
  }
}
