import XCTest
@testable import BeerParty

@MainActor
final class DrinkHistoryTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private let me = UUID()
  private let friend = UUID()

  private func drink(_ name: String = "Beer", by userID: UUID, minutesAgo: Double) -> LobbyDrink {
    LobbyDrink(
      id: UUID(),
      userId: userID,
      name: name,
      volumeMl: 330,
      abv: 5,
      consumedAt: now.addingTimeInterval(-minutesAgo * 60)
    )
  }

  private func canModify(_ drink: LobbyDrink, lobbyOpen: Bool = true, user: UUID? = nil) -> Bool {
    DrinkHistory.canModify(drink, currentUserID: user ?? me, isLobbyActive: lobbyOpen, now: now)
  }

  // MARK: which drinks are listed

  func testOnlyTheUsersOwnDrinksAreListedNewestFirst() {
    let old = drink("Old", by: me, minutesAgo: 90)
    let new = drink("New", by: me, minutesAgo: 5)
    let middle = drink("Middle", by: me, minutesAgo: 30)
    let theirs = drink("Theirs", by: friend, minutesAgo: 10)

    let listed = DrinkHistory.ownDrinks(in: [old, theirs, new, middle], userID: me)
    XCTAssertEqual(listed.map(\.name), ["New", "Middle", "Old"])
  }

  func testNothingIsListedWhileTheUserIsNotKnown() {
    XCTAssertEqual(DrinkHistory.ownDrinks(in: [drink(by: me, minutesAgo: 5)], userID: nil), [])
  }

  func testNothingIsListedWithoutDrinks() {
    XCTAssertEqual(DrinkHistory.ownDrinks(in: [], userID: me), [])
  }

  // MARK: which drinks can be changed

  func testAFreshOwnDrinkCanBeChanged() {
    XCTAssertTrue(canModify(drink(by: me, minutesAgo: 0)))
    XCTAssertTrue(canModify(drink(by: me, minutesAgo: 14)))
  }

  func testTheWindowIsFifteenMinutesInclusive() {
    XCTAssertTrue(canModify(drink(by: me, minutesAgo: 15)))
    XCTAssertFalse(canModify(drink(by: me, minutesAgo: 15.1)))
    XCTAssertEqual(DrinkHistory.editWindow, 15 * 60)
  }

  func testSomeoneElsesDrinkCannotBeChanged() {
    XCTAssertFalse(canModify(drink(by: friend, minutesAgo: 1)))
  }

  func testNothingCanBeChangedWhileTheUserIsNotKnown() {
    XCTAssertFalse(DrinkHistory.canModify(
      drink(by: me, minutesAgo: 1), currentUserID: nil, isLobbyActive: true, now: now))
  }

  func testNothingCanBeChangedInAClosedLobby() {
    XCTAssertFalse(canModify(drink(by: me, minutesAgo: 1), lobbyOpen: false))
  }

  // A drink stamped later than this phone's clock is left alone.
  func testADrinkFromTheFutureCannotBeChanged() {
    XCTAssertFalse(canModify(drink(by: me, minutesAgo: -1)))
  }

  func testASystemEventRowCannotBeChanged() {
    let event = drink("\(LobbyBackendService.madeItHomeDrinkPrefix)Anna", by: me, minutesAgo: 1)
    XCTAssertFalse(canModify(event))
  }
}
