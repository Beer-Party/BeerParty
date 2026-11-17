import XCTest
@testable import BeerParty

@MainActor
final class BACSnapshotCacheTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_800_000_000)
  private let anna = LobbyMemberData(userId: UUID(), nickname: "Anna", profilePicPath: nil)
  private let ben = LobbyMemberData(userId: UUID(), nickname: "Ben", profilePicPath: nil)

  private func beer(for member: LobbyMemberData, minutesAfterStart: Double) -> LobbyDrink {
    LobbyDrink(
      id: UUID(),
      userId: member.userId,
      name: "Beer",
      volumeMl: 330,
      abv: 5,
      consumedAt: start.addingTimeInterval(minutesAfterStart * 60)
    )
  }

  func testSameInputsRunTheSimulationOnce() {
    let cache = BACSnapshotCache()
    let drinks = [beer(for: anna, minutesAfterStart: 0)]
    let now = start.addingTimeInterval(3600)

    let first = cache.snapshot(members: [anna, ben], drinks: drinks, paramsByUserId: [:], at: now)
    let second = cache.snapshot(members: [anna, ben], drinks: drinks, paramsByUserId: [:], at: now)
    _ = cache.snapshot(members: [anna, ben], drinks: drinks, paramsByUserId: [:], at: now)

    XCTAssertEqual(cache.simulationCount, 1)
    XCTAssertEqual(first.current.map(\.bac), second.current.map(\.bac))
    XCTAssertEqual(first.points.map(\.id), second.points.map(\.id))
  }

  func testCachedSnapshotMatchesTheCalculator() {
    let cache = BACSnapshotCache()
    let drinks = [beer(for: anna, minutesAfterStart: 0), beer(for: ben, minutesAfterStart: 20)]
    let now = start.addingTimeInterval(5400)

    _ = cache.snapshot(members: [anna, ben], drinks: drinks, paramsByUserId: [:], at: now)
    let cached = cache.snapshot(members: [anna, ben], drinks: drinks, paramsByUserId: [:], at: now)
    let direct = BACCalculator.snapshot(members: [anna, ben], drinks: drinks, paramsByUserId: [:], at: now)

    XCTAssertEqual(cached.current.map(\.userId), direct.current.map(\.userId))
    XCTAssertEqual(cached.current.map(\.bac), direct.current.map(\.bac))
    XCTAssertEqual(cached.points.map(\.bac), direct.points.map(\.bac))
    XCTAssertEqual(cached.maxY, direct.maxY)
  }

  func testANewDrinkRunsTheSimulationAgain() {
    let cache = BACSnapshotCache()
    let now = start.addingTimeInterval(3600)
    let oneDrink = [beer(for: anna, minutesAfterStart: 0)]
    let twoDrinks = oneDrink + [beer(for: anna, minutesAfterStart: 30)]

    let before = cache.snapshot(members: [anna], drinks: oneDrink, paramsByUserId: [:], at: now)
    let after = cache.snapshot(members: [anna], drinks: twoDrinks, paramsByUserId: [:], at: now)

    XCTAssertEqual(cache.simulationCount, 2)
    XCTAssertGreaterThan(after.current[0].bac, before.current[0].bac)
  }

  func testTheClockMovingOnRunsTheSimulationAgain() {
    let cache = BACSnapshotCache()
    let drinks = [beer(for: anna, minutesAfterStart: 0)]

    _ = cache.snapshot(members: [anna], drinks: drinks, paramsByUserId: [:], at: start.addingTimeInterval(3600))
    _ = cache.snapshot(members: [anna], drinks: drinks, paramsByUserId: [:], at: start.addingTimeInterval(3630))

    XCTAssertEqual(cache.simulationCount, 2)
  }

  func testAMemberJoiningOrNewBodyParametersRunTheSimulationAgain() {
    let cache = BACSnapshotCache()
    let drinks = [beer(for: anna, minutesAfterStart: 0)]
    let now = start.addingTimeInterval(3600)
    let params = [anna.userId: LobbyBACParamsData(userId: anna.userId, tbw: 45, eliminationPerHourPromille: 0.15)]

    _ = cache.snapshot(members: [anna], drinks: drinks, paramsByUserId: [:], at: now)
    _ = cache.snapshot(members: [anna, ben], drinks: drinks, paramsByUserId: [:], at: now)
    XCTAssertEqual(cache.simulationCount, 2)

    _ = cache.snapshot(members: [anna, ben], drinks: drinks, paramsByUserId: params, at: now)
    XCTAssertEqual(cache.simulationCount, 3)
  }
}
