import XCTest
@testable import BeerParty

@MainActor
final class BACCalculatorTests: XCTestCase {

  private let start = Date(timeIntervalSince1970: 1_800_000_000)

  private func drink(
    user: UUID = UUID(),
    volumeMl: Double = 330,
    abv: Double = 5,
    minutesAfterStart: Double = 0
  ) -> LobbyDrink {
    LobbyDrink(
      id: UUID(),
      userId: user,
      name: "Test",
      volumeMl: volumeMl,
      abv: abv,
      consumedAt: start.addingTimeInterval(minutesAfterStart * 60)
    )
  }

  // MARK: absorption

  func testNothingIsAbsorbedBeforeTheDrink() {
    XCTAssertEqual(BACCalculator.absorbedFraction(hoursSinceDrink: 0, abv: 5), 0)
    XCTAssertEqual(BACCalculator.absorbedFraction(hoursSinceDrink: -1, abv: 5), 0)
  }

  // A 5% beer is absorbed over 1.6 - 5 * 0.03 = 1.45 hours.
  func testBeerIsAbsorbedLinearlyOverItsWindow() {
    XCTAssertEqual(BACCalculator.absorbedFraction(hoursSinceDrink: 0.725, abv: 5), 0.5, accuracy: 1e-9)
    XCTAssertEqual(BACCalculator.absorbedFraction(hoursSinceDrink: 1.45, abv: 5), 1, accuracy: 1e-9)
    XCTAssertEqual(BACCalculator.absorbedFraction(hoursSinceDrink: 6, abv: 5), 1)
  }

  // Stronger drinks absorb faster, but never in under 15 minutes.
  func testStrongDrinksAbsorbFasterWithAFloor() {
    XCTAssertEqual(BACCalculator.absorbedFraction(hoursSinceDrink: 0.2, abv: 40), 0.5, accuracy: 1e-9)
    XCTAssertEqual(BACCalculator.absorbedFraction(hoursSinceDrink: 0.125, abv: 80), 0.5, accuracy: 1e-9)
  }

  // MARK: parameters

  func testMissingParametersUseDefaults() {
    let parameters = BACCalculator.parameters(for: nil)
    XCTAssertEqual(parameters.tbw, 40)
    XCTAssertEqual(parameters.eliminationPerHourPromille, 0.14)
  }

  func testParametersAreClampedToSaneRanges() {
    let low = BACCalculator.parameters(
      for: LobbyBACParamsData(userId: UUID(), tbw: 5, eliminationPerHourPromille: 0.01)
    )
    XCTAssertEqual(low.tbw, 20)
    XCTAssertEqual(low.eliminationPerHourPromille, 0.08)

    let high = BACCalculator.parameters(
      for: LobbyBACParamsData(userId: UUID(), tbw: 55, eliminationPerHourPromille: 0.9)
    )
    XCTAssertEqual(high.tbw, 55)
    XCTAssertEqual(high.eliminationPerHourPromille, 0.2)
  }

  // MARK: timeline

  func testNoDrinksMeansZero() {
    let result = BACCalculator.simulateTimeline(
      params: nil, drinks: [], start: start, end: start.addingTimeInterval(3600), stepMinutes: 10
    )
    XCTAssertEqual(result.currentBAC, 0)
    XCTAssertEqual(result.points.count, 7)
    XCTAssertTrue(result.points.allSatisfy { $0.bac == 0 })
  }

  func testEndBeforeStartGivesASingleZeroPoint() {
    let result = BACCalculator.simulateTimeline(
      params: nil, drinks: [drink()], start: start, end: start.addingTimeInterval(-60), stepMinutes: 10
    )
    XCTAssertEqual(result.currentBAC, 0)
    XCTAssertEqual(result.points.count, 1)
  }

  // One 330 ml 5% beer is 13.0185 g of alcohol. With the default parameters
  // (40 l body water, 0.14 per hour) an hour later 13.0185 / 1.45 = 8.9783 g is
  // absorbed and 0.14 * 40 / 0.84 = 6.6667 g eliminated, leaving 2.3116 g:
  // 2.3116 / 40 * 0.84 = 0.04854.
  func testOneBeerAfterOneHour() {
    let result = BACCalculator.simulateTimeline(
      params: nil, drinks: [drink()], start: start, end: start.addingTimeInterval(3600), stepMinutes: 10
    )
    XCTAssertEqual(result.currentBAC, 0.04854, accuracy: 0.0001)
  }

  func testOneBeerIsGoneByTheNextMorning() {
    let result = BACCalculator.simulateTimeline(
      params: nil, drinks: [drink()], start: start, end: start.addingTimeInterval(10 * 3600), stepMinutes: 10
    )
    XCTAssertEqual(result.currentBAC, 0)
    XCTAssertTrue(result.points.allSatisfy { $0.bac >= 0 })
  }

  func testWaterDoesNotRaiseBAC() {
    let result = BACCalculator.simulateTimeline(
      params: nil,
      drinks: [drink(volumeMl: 250, abv: 0)],
      start: start,
      end: start.addingTimeInterval(3600),
      stepMinutes: 10
    )
    XCTAssertEqual(result.currentBAC, 0)
  }

  func testMoreBodyWaterMeansLowerBAC() {
    let end = start.addingTimeInterval(3600)
    let small = BACCalculator.simulateTimeline(
      params: LobbyBACParamsData(userId: UUID(), tbw: 30, eliminationPerHourPromille: 0.14),
      drinks: [drink()], start: start, end: end, stepMinutes: 10
    )
    let large = BACCalculator.simulateTimeline(
      params: LobbyBACParamsData(userId: UUID(), tbw: 50, eliminationPerHourPromille: 0.14),
      drinks: [drink()], start: start, end: end, stepMinutes: 10
    )
    XCTAssertGreaterThan(small.currentBAC, large.currentBAC)
  }

  // MARK: snapshot

  func testSnapshotRanksMembersByBACAndKeepsSoberMembers() {
    let anna = LobbyMemberData(userId: UUID(), nickname: "Anna", profilePicPath: nil)
    let ben = LobbyMemberData(userId: UUID(), nickname: "Ben", profilePicPath: nil)
    let cleo = LobbyMemberData(userId: UUID(), nickname: "Cleo", profilePicPath: nil)
    let drinks = [
      drink(user: ben.userId),
      drink(user: ben.userId, minutesAfterStart: 10),
      drink(user: cleo.userId)
    ]

    let snapshot = BACCalculator.snapshot(
      members: [cleo, anna, ben],
      drinks: drinks,
      paramsByUserId: [:],
      at: start.addingTimeInterval(3600)
    )

    XCTAssertEqual(snapshot.current.map(\.nickname), ["Ben", "Cleo", "Anna"])
    XCTAssertEqual(snapshot.current.last?.bac, 0)
    XCTAssertGreaterThanOrEqual(snapshot.maxY, 0.05)
    // Seven points per member: the start plus six 10-minute steps.
    XCTAssertEqual(snapshot.points.count, 21)
  }

  func testSnapshotWithoutDrinksHasNoGraphPoints() {
    let anna = LobbyMemberData(userId: UUID(), nickname: "Anna", profilePicPath: nil)
    let snapshot = BACCalculator.snapshot(members: [anna], drinks: [], paramsByUserId: [:], at: start)
    XCTAssertTrue(snapshot.points.isEmpty)
    XCTAssertEqual(snapshot.current.map(\.bac), [0])
    XCTAssertEqual(snapshot.maxY, 0.05)
  }
}
