import MapKit
import XCTest
@testable import BeerParty

@MainActor
final class MemberMapFramingTests: XCTestCase {
  private func coordinate(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  private func contains(_ region: MKCoordinateRegion, _ point: CLLocationCoordinate2D) -> Bool {
    abs(point.latitude - region.center.latitude) <= region.span.latitudeDelta / 2
      && abs(point.longitude - region.center.longitude) <= region.span.longitudeDelta / 2
  }

  func testNoMembersGivesNoRegion() {
    XCTAssertNil(MemberMapFraming.region(for: []))
  }

  func testOneMemberIsCentredAtTheClosestZoom() throws {
    let region = try XCTUnwrap(MemberMapFraming.region(for: [coordinate(59.91, 10.75)]))

    XCTAssertEqual(region.center.latitude, 59.91, accuracy: 0.000001)
    XCTAssertEqual(region.center.longitude, 10.75, accuracy: 0.000001)
    XCTAssertEqual(region.span.latitudeDelta, MemberMapFraming.minimumSpanDegrees)
    XCTAssertEqual(region.span.longitudeDelta, MemberMapFraming.minimumSpanDegrees)
  }

  func testAllMembersAreInsideTheRegionWithRoomToSpare() throws {
    let members = [
      coordinate(59.91, 10.75),
      coordinate(59.95, 10.60),
      coordinate(59.80, 10.90)
    ]
    let region = try XCTUnwrap(MemberMapFraming.region(for: members))

    XCTAssertEqual(region.center.latitude, 59.875, accuracy: 0.000001)
    XCTAssertEqual(region.center.longitude, 10.75, accuracy: 0.000001)
    XCTAssertEqual(region.span.latitudeDelta, 0.15 * MemberMapFraming.paddingFactor, accuracy: 0.000001)
    XCTAssertEqual(region.span.longitudeDelta, 0.30 * MemberMapFraming.paddingFactor, accuracy: 0.000001)
    for member in members {
      XCTAssertTrue(contains(region, member))
    }
  }

  // Two members at the same bar must not zoom the map in to a few metres.
  func testMembersCloseTogetherKeepTheMinimumSpan() throws {
    let region = try XCTUnwrap(
      MemberMapFraming.region(for: [coordinate(59.9100, 10.7500), coordinate(59.9101, 10.7501)])
    )

    XCTAssertEqual(region.span.latitudeDelta, MemberMapFraming.minimumSpanDegrees)
    XCTAssertEqual(region.span.longitudeDelta, MemberMapFraming.minimumSpanDegrees)
  }

  func testInvalidCoordinatesAreIgnored() throws {
    XCTAssertNil(MemberMapFraming.region(for: [coordinate(123, 500)]))

    let region = try XCTUnwrap(
      MemberMapFraming.region(for: [coordinate(123, 500), coordinate(59.91, 10.75)])
    )
    XCTAssertEqual(region.center.latitude, 59.91, accuracy: 0.000001)
    XCTAssertEqual(region.center.longitude, 10.75, accuracy: 0.000001)
  }

  func testSpanNeverExceedsTheWholeWorld() throws {
    let region = try XCTUnwrap(
      MemberMapFraming.region(for: [coordinate(-89, -179), coordinate(89, 179)])
    )

    XCTAssertEqual(region.span.latitudeDelta, 180)
    XCTAssertEqual(region.span.longitudeDelta, 360)
  }
}
