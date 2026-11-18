import XCTest
@testable import BeerParty

@MainActor
final class BACGraphWindowTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_800_000_000)

  private let annaID = UUID()
  private let benID = UUID()

  private func point(_ nickname: String, hour: Double, bac: Double) -> BACPoint {
    point(nickname, userId: nickname == "Anna" ? annaID : benID, hour: hour, bac: bac)
  }

  private func point(_ nickname: String, userId: UUID, hour: Double, bac: Double) -> BACPoint {
    BACPoint(
      id: "\(userId.uuidString)-\(hour)",
      userId: userId,
      nickname: nickname,
      label: nickname,
      time: start.addingTimeInterval(hour * 3600),
      bac: bac
    )
  }

  // Anna has a point every hour from 0h to 6h; Ben from 4h to 6h.
  private var sixHourSnapshot: BacSnapshot {
    let anna = (0...6).map { point("Anna", hour: Double($0), bac: 0.1 * Double($0 + 1)) }
    let ben = (4...6).map { point("Ben", hour: Double($0), bac: 0.2) }
    return BacSnapshot(current: [], points: anna + ben, maxY: 0.7)
  }

  func testNoPointsGivesAnEmptyGraph() {
    let now = start.addingTimeInterval(60)
    let data = BACGraphWindow.displayData(
      snapshot: BacSnapshot(current: [], points: [], maxY: 0.05),
      now: now,
      timeframeDuration: nil,
      customVisibleDuration: nil
    )

    XCTAssertTrue(data.points.isEmpty)
    XCTAssertTrue(data.latestPointByMember.isEmpty)
    XCTAssertEqual(data.xDomain, now...now)
    XCTAssertEqual(data.maxY, 0.05)
    XCTAssertNil(data.baseDuration)
    XCTAssertNil(data.visibleDuration)
  }

  func testAllTimeframeShowsEveryPoint() {
    let data = BACGraphWindow.displayData(
      snapshot: sixHourSnapshot,
      now: start,
      timeframeDuration: nil,
      customVisibleDuration: nil
    )

    XCTAssertEqual(data.points.count, 10)
    XCTAssertEqual(data.xDomain, start...start.addingTimeInterval(6 * 3600))
    XCTAssertEqual(data.baseDuration, 6 * 3600)
    XCTAssertEqual(data.visibleDuration, 6 * 3600)
    XCTAssertEqual(data.maxY, 0.7, accuracy: 0.0001)
  }

  func testTwoHourTimeframeKeepsOnlyTheLastTwoHours() {
    let data = BACGraphWindow.displayData(
      snapshot: sixHourSnapshot,
      now: start,
      timeframeDuration: 2 * 3600,
      customVisibleDuration: nil
    )

    XCTAssertEqual(data.xDomain, start.addingTimeInterval(4 * 3600)...start.addingTimeInterval(6 * 3600))
    XCTAssertEqual(data.points.filter { $0.nickname == "Anna" }.count, 3)
    XCTAssertEqual(data.points.filter { $0.nickname == "Ben" }.count, 3)
    XCTAssertEqual(data.baseDuration, 2 * 3600)
  }

  // A timeframe longer than the recorded history starts at the first point.
  func testTimeframeLongerThanTheHistoryStartsAtTheFirstPoint() {
    let data = BACGraphWindow.displayData(
      snapshot: sixHourSnapshot,
      now: start,
      timeframeDuration: 24 * 3600,
      customVisibleDuration: nil
    )

    XCTAssertEqual(data.xDomain.lowerBound, start)
    XCTAssertEqual(data.points.count, 10)
  }

  func testPinchingInShowsTheNewestPartOnly() {
    let data = BACGraphWindow.displayData(
      snapshot: sixHourSnapshot,
      now: start,
      timeframeDuration: nil,
      customVisibleDuration: 3600
    )

    XCTAssertEqual(data.visibleDuration, 3600)
    XCTAssertEqual(data.baseDuration, 6 * 3600)
    XCTAssertEqual(data.xDomain, start.addingTimeInterval(5 * 3600)...start.addingTimeInterval(6 * 3600))
    XCTAssertEqual(data.points.count, 4)
  }

  func testPinchIsLimitedToTwentyMinutesAndToTheTimeframe() {
    let tooClose = BACGraphWindow.displayData(
      snapshot: sixHourSnapshot,
      now: start,
      timeframeDuration: nil,
      customVisibleDuration: 60
    )
    XCTAssertEqual(tooClose.visibleDuration, BACGraphWindow.minimumVisibleDuration)

    let tooFar = BACGraphWindow.displayData(
      snapshot: sixHourSnapshot,
      now: start,
      timeframeDuration: 2 * 3600,
      customVisibleDuration: 50 * 3600
    )
    XCTAssertEqual(tooFar.visibleDuration, 2 * 3600)
  }

  func testLatestPointPerMemberIsTheNewestVisibleOne() {
    let data = BACGraphWindow.displayData(
      snapshot: sixHourSnapshot,
      now: start,
      timeframeDuration: nil,
      customVisibleDuration: nil
    )

    XCTAssertEqual(data.latestPointByMember[annaID]?.time, start.addingTimeInterval(6 * 3600))
    XCTAssertEqual(data.latestPointByMember[benID]?.time, start.addingTimeInterval(6 * 3600))
    XCTAssertEqual(data.latestPointByMember.count, 2)
  }

  // Two members who chose the same nickname are still two lines.
  func testMembersWithTheSameNicknameEachKeepTheirOwnLatestPoint() {
    let secondAnnaID = UUID()
    let first = (0...2).map { point("Anna", hour: Double($0), bac: 0.1) }
    let second = (0...3).map { point("Anna", userId: secondAnnaID, hour: Double($0), bac: 0.3) }
    let data = BACGraphWindow.displayData(
      snapshot: BacSnapshot(current: [], points: first + second, maxY: 0.3),
      now: start,
      timeframeDuration: nil,
      customVisibleDuration: nil
    )

    XCTAssertEqual(data.latestPointByMember.count, 2)
    XCTAssertEqual(data.latestPointByMember[annaID]?.time, start.addingTimeInterval(2 * 3600))
    XCTAssertEqual(data.latestPointByMember[secondAnnaID]?.time, start.addingTimeInterval(3 * 3600))
  }

  // The y-axis follows the visible points, but never shrinks below 0.05.
  func testMaxYFollowsTheVisiblePointsWithAFloor() {
    let low = BacSnapshot(
      current: [],
      points: [point("Anna", hour: 0, bac: 0.01), point("Anna", hour: 1, bac: 0.02)],
      maxY: 0.05
    )
    let data = BACGraphWindow.displayData(
      snapshot: low,
      now: start,
      timeframeDuration: nil,
      customVisibleDuration: nil
    )
    XCTAssertEqual(data.maxY, 0.05)

    let zoomed = BACGraphWindow.displayData(
      snapshot: sixHourSnapshot,
      now: start,
      timeframeDuration: nil,
      customVisibleDuration: 3600
    )
    XCTAssertEqual(zoomed.maxY, 0.7, accuracy: 0.0001)
  }
}
