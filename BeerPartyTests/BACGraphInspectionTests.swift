import XCTest
@testable import BeerParty

@MainActor
final class BACGraphInspectionTests: XCTestCase {

  private let start = Date(timeIntervalSince1970: 1_700_000_000)
  private let anna = UUID()
  private let ben = UUID()

  private func point(_ name: String, user: UUID, minutes: Double, bac: Double) -> BACPoint {
    BACPoint(
      id: "\(name)-\(minutes)",
      userId: user,
      nickname: name,
      label: name,
      time: start.addingTimeInterval(minutes * 60),
      bac: bac
    )
  }

  private func nearest(
    in points: [BACPoint],
    minutes: Double,
    bac: Double?,
    maxY: Double = 1.0
  ) -> BACPoint? {
    BACGraphInspection.nearestPoint(
      in: points,
      hoveredTime: start.addingTimeInterval(minutes * 60),
      hoveredBAC: bac,
      maxY: maxY
    )
  }

  func testNoPointsGivesNothing() {
    XCTAssertNil(nearest(in: [], minutes: 0, bac: 0.5))
  }

  func testPicksThePointClosestInTime() {
    let points = [
      point("Anna", user: anna, minutes: 0, bac: 0.2),
      point("Anna", user: anna, minutes: 10, bac: 0.2),
      point("Anna", user: anna, minutes: 20, bac: 0.2)
    ]
    XCTAssertEqual(nearest(in: points, minutes: 12, bac: 0.2)?.id, "Anna-10.0")
  }

  func testAtTheSameTimePicksTheLineClosestToTheFinger() {
    let points = [
      point("Anna", user: anna, minutes: 10, bac: 0.2),
      point("Ben", user: ben, minutes: 10, bac: 0.8)
    ]
    XCTAssertEqual(nearest(in: points, minutes: 10, bac: 0.7)?.userId, ben)
    XCTAssertEqual(nearest(in: points, minutes: 10, bac: 0.3)?.userId, anna)
  }

  func testWithoutABACValueOnlyTimeCounts() {
    let points = [
      point("Anna", user: anna, minutes: 10, bac: 0.2),
      point("Ben", user: ben, minutes: 11, bac: 0.8)
    ]
    XCTAssertEqual(nearest(in: points, minutes: 10.9, bac: nil)?.userId, ben)
  }

  func testEqualDistanceKeepsTheFirstPoint() {
    let points = [
      point("Anna", user: anna, minutes: 10, bac: 0.5),
      point("Ben", user: ben, minutes: 10, bac: 0.5)
    ]
    XCTAssertEqual(nearest(in: points, minutes: 10, bac: 0.5)?.userId, anna)
  }

  func testTwoMinutesCountAsMuchAsTheWholeGraphHeight() {
    let onTheLine = point("Anna", user: anna, minutes: 2, bac: 1.0)
    let score = BACGraphInspection.distanceScore(
      point: onTheLine,
      hoveredTime: start,
      hoveredBAC: 0.0,
      maxY: 1.0
    )
    XCTAssertEqual(score, 2.0, accuracy: 0.0001)
  }

  func testAFlatGraphUsesTheMinimumHeight() {
    let flat = point("Anna", user: anna, minutes: 0, bac: 0.01)
    let score = BACGraphInspection.distanceScore(
      point: flat,
      hoveredTime: start,
      hoveredBAC: 0.0,
      maxY: 0.0
    )
    XCTAssertEqual(score, 0.01 / 0.05, accuracy: 0.0001)
  }
}
