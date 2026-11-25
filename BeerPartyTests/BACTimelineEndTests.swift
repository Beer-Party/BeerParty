import XCTest
@testable import BeerParty

@MainActor
final class BACTimelineEndTests: XCTestCase {

  private let start = Date(timeIntervalSince1970: 1_800_000_000)
  private let anna = LobbyMemberData(userId: UUID(), nickname: "Anna", profilePicPath: nil)
  private let ben = LobbyMemberData(userId: UUID(), nickname: "Ben", profilePicPath: nil)

  private func beer(for member: LobbyMemberData, minutesAfterStart: Double = 0) -> LobbyDrink {
    LobbyDrink(
      id: UUID(),
      userId: member.userId,
      name: "Beer",
      volumeMl: 330,
      abv: 5,
      consumedAt: start.addingTimeInterval(minutesAfterStart * 60)
    )
  }

  private func end(
    members: [LobbyMemberData],
    drinks: [LobbyDrink],
    minutesAfterStart: Double
  ) -> Date {
    BACCalculator.timelineEnd(
      members: members,
      drinks: drinks,
      paramsByUserId: [:],
      now: start.addingTimeInterval(minutesAfterStart * 60)
    )
  }

  private func minutes(_ date: Date) -> Double {
    date.timeIntervalSince(start) / 60
  }

  // One 330 ml 5% beer with the default parameters: 13.0185 g, all absorbed
  // after 87 minutes, 6.6667 g eliminated per hour. After 110 minutes 0.80 g is
  // left, so the first step at zero is the one at 120 minutes.
  func testPastLobbyEndsWhenTheLastMemberIsBackAtZero() {
    let aWeekLater = 7.0 * 24 * 60
    let result = end(members: [anna], drinks: [beer(for: anna)], minutesAfterStart: aWeekLater)
    XCTAssertEqual(minutes(result), 120, accuracy: 0.01)
  }

  func testEveningStillGoingEndsNow() {
    let result = end(members: [anna], drinks: [beer(for: anna)], minutesAfterStart: 60)
    XCTAssertEqual(minutes(result), 60, accuracy: 0.01)
  }

  func testNeverLaterThanNowAlsoBetweenTwoSteps() {
    let result = end(members: [anna], drinks: [beer(for: anna)], minutesAfterStart: 95)
    XCTAssertEqual(minutes(result), 95, accuracy: 0.01)
  }

  // Ben's beer is an hour after Anna's, so he is the last one back at zero.
  func testTheMemberWhoIsSoberLastDecides() {
    let drinks = [beer(for: anna), beer(for: ben, minutesAfterStart: 60)]
    let result = end(members: [anna, ben], drinks: drinks, minutesAfterStart: 24 * 60)
    XCTAssertEqual(minutes(result), 180, accuracy: 0.01)
  }

  func testMembersWithoutDrinksDoNotMatter() {
    let result = end(members: [anna, ben], drinks: [beer(for: anna)], minutesAfterStart: 24 * 60)
    XCTAssertEqual(minutes(result), 120, accuracy: 0.01)
  }

  func testNoDrinksEndsNow() {
    let result = end(members: [anna], drinks: [], minutesAfterStart: 30)
    XCTAssertEqual(minutes(result), 30, accuracy: 0.01)
  }

  // A drink "from the future" (the other phone's clock is ahead).
  func testDrinkAfterNowEndsNow() {
    let result = end(members: [anna], drinks: [beer(for: anna, minutesAfterStart: 10)], minutesAfterStart: 0)
    XCTAssertEqual(minutes(result), 0, accuracy: 0.01)
  }

  func testStoppingWhenSoberGivesTheSameValuesUpToThatPoint() {
    let drinks = [beer(for: anna)]
    let late = start.addingTimeInterval(10 * 3600)
    let full = BACCalculator.simulateTimeline(
      params: nil, drinks: drinks, start: start, end: late, stepMinutes: 10
    )
    let short = BACCalculator.simulateTimeline(
      params: nil, drinks: drinks, start: start, end: late, stepMinutes: 10, stopsWhenSober: true
    )
    // The start plus twelve 10-minute steps.
    XCTAssertEqual(short.points.count, 13)
    XCTAssertEqual(short.currentBAC, 0)
    XCTAssertEqual(short.points.map(\.bac), Array(full.points.map(\.bac).prefix(13)))
    XCTAssertTrue(full.points.dropFirst(13).allSatisfy { $0.bac == 0 })
  }

  // The graph of last week's lobby covers the evening, not the week.
  func testSnapshotOfAPastLobbyStopsAtTheEndOfTheEvening() {
    let drinks = [beer(for: anna), beer(for: ben, minutesAfterStart: 60)]
    let aWeekLater = start.addingTimeInterval(7 * 24 * 3600)

    let snapshot = BACCalculator.snapshot(
      members: [anna, ben],
      drinks: drinks,
      paramsByUserId: [:],
      at: aWeekLater
    )

    let lastTime = snapshot.points.map(\.time).max() ?? aWeekLater
    XCTAssertEqual(minutes(lastTime), 180, accuracy: 0.01)
    // Both lines run over the same time: the start plus eighteen steps each.
    XCTAssertEqual(snapshot.points.filter { $0.userId == anna.userId }.count, 19)
    XCTAssertEqual(snapshot.points.filter { $0.userId == ben.userId }.count, 19)
    XCTAssertEqual(snapshot.current.map(\.bac), [0, 0])
  }

  // During the evening nothing changes: the last point is "now".
  func testSnapshotOfARunningEveningStillEndsNow() {
    let now = start.addingTimeInterval(45 * 60)
    let snapshot = BACCalculator.snapshot(
      members: [anna],
      drinks: [beer(for: anna)],
      paramsByUserId: [:],
      at: now
    )
    XCTAssertEqual(snapshot.points.map(\.time).max(), now)
    XCTAssertGreaterThan(snapshot.current.first?.bac ?? 0, 0)
  }
}
