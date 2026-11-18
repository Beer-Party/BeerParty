import XCTest
@testable import BeerParty

@MainActor
final class LobbySystemEventTests: XCTestCase {
  private let rowTime = Date(timeIntervalSince1970: 1_800_000_000)

  private func row(named name: String) -> LobbyDrink {
    LobbyDrink(id: UUID(), userId: UUID(), name: name, volumeMl: 0, abv: 0, consumedAt: rowTime)
  }

  // MARK: real drinks

  func testAnOrdinaryDrinkIsNotAnEvent() {
    let beer = LobbyDrink(id: UUID(), userId: UUID(), name: "Beer", volumeMl: 330, abv: 5, consumedAt: rowTime)
    XCTAssertFalse(LobbySystemEvent.isSystemEvent(beer))
    XCTAssertNil(LobbySystemEvent.madeItHomeNickname(from: beer))
    XCTAssertNil(LobbySystemEvent.closedAtTime(from: beer))
    XCTAssertNil(LobbySystemEvent.motionArrivalTarget(from: beer))
  }

  func testAPrefixInTheMiddleOfANameDoesNotCount() {
    XCTAssertFalse(LobbySystemEvent.isSystemEvent(row(named: "My __home__: brew")))
  }

  // MARK: made it home

  func testMadeItHomeCarriesTheNickname() {
    let event = row(named: "\(LobbyBackendService.madeItHomeDrinkPrefix)Anna")
    XCTAssertTrue(LobbySystemEvent.isSystemEvent(event))
    XCTAssertEqual(LobbySystemEvent.madeItHomeNickname(from: event), "Anna")
    XCTAssertNil(LobbySystemEvent.closedAtTime(from: event))
    XCTAssertNil(LobbySystemEvent.motionArrivalTarget(from: event))
  }

  func testMadeItHomeWithoutANicknameSaysMember() {
    XCTAssertEqual(
      LobbySystemEvent.madeItHomeNickname(from: row(named: LobbyBackendService.madeItHomeDrinkPrefix)),
      "Member"
    )
    XCTAssertEqual(
      LobbySystemEvent.madeItHomeNickname(from: row(named: "\(LobbyBackendService.madeItHomeDrinkPrefix)   ")),
      "Member"
    )
  }

  // MARK: lobby closed

  func testLobbyClosedReadsTheTimeWithFractionalSeconds() {
    let event = row(named: "\(LobbyBackendService.lobbyClosedDrinkPrefix)2027-01-15T08:00:00.500Z|Anna")
    let closedAt = LobbySystemEvent.closedAtTime(from: event)
    XCTAssertTrue(LobbySystemEvent.isSystemEvent(event))
    XCTAssertEqual(closedAt?.timeIntervalSince1970 ?? 0, 1_800_000_000.5, accuracy: 0.001)
  }

  func testLobbyClosedReadsTheTimeWithoutFractionalSeconds() {
    let event = row(named: "\(LobbyBackendService.lobbyClosedDrinkPrefix)2027-01-15T08:00:10Z|Anna")
    XCTAssertEqual(
      LobbySystemEvent.closedAtTime(from: event),
      Date(timeIntervalSince1970: 1_800_000_010)
    )
  }

  func testLobbyClosedFallsBackToTheRowTime() {
    let noTime = row(named: LobbyBackendService.lobbyClosedDrinkPrefix)
    let unreadable = row(named: "\(LobbyBackendService.lobbyClosedDrinkPrefix)yesterday|Anna")
    XCTAssertEqual(LobbySystemEvent.closedAtTime(from: noTime), rowTime)
    XCTAssertEqual(LobbySystemEvent.closedAtTime(from: unreadable), rowTime)
    XCTAssertTrue(LobbySystemEvent.isSystemEvent(noTime))
  }

  // MARK: motion due

  func testMotionDueCarriesTheTarget() {
    let event = row(named: "\(LobbyBackendService.motionArrivedDrinkPrefix)\(UUID().uuidString)|The Red Lion")
    XCTAssertTrue(LobbySystemEvent.isSystemEvent(event))
    XCTAssertEqual(LobbySystemEvent.motionArrivalTarget(from: event), "The Red Lion")
  }

  func testMotionDueKeepsALaterBarInTheTarget() {
    let event = row(named: "\(LobbyBackendService.motionArrivedDrinkPrefix)id|Bar A | Bar B")
    XCTAssertEqual(LobbySystemEvent.motionArrivalTarget(from: event), "Bar A | Bar B")
  }

  func testMotionDueWithAnEmptyTargetSaysTheDestination() {
    let event = row(named: "\(LobbyBackendService.motionArrivedDrinkPrefix)id|  ")
    XCTAssertEqual(LobbySystemEvent.motionArrivalTarget(from: event), "the destination")
  }

  // As before the move: without the "|" the row is not read as an event.
  func testMotionDueWithoutASeparatorIsNotAnEvent() {
    let event = row(named: "\(LobbyBackendService.motionArrivedDrinkPrefix)id-only")
    XCTAssertNil(LobbySystemEvent.motionArrivalTarget(from: event))
    XCTAssertFalse(LobbySystemEvent.isSystemEvent(event))
  }
}
