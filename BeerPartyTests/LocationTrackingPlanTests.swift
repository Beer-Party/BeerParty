import XCTest
import CoreLocation
@testable import BeerParty

@MainActor
final class LocationTrackingPlanTests: XCTestCase {

  private let allStatuses: [CLAuthorizationStatus] = [
    .notDetermined, .restricted, .denied, .authorizedWhenInUse, .authorizedAlways,
  ]

  func testAsksForPermissionWhenNeverAsked() {
    XCTAssertEqual(
      LocationTrackingPlan.step(wantsTracking: true, status: .notDetermined),
      .askPermission
    )
  }

  // The bug this replaces: after the user tapped "Allow", nothing started.
  func testStartsOncePermissionIsGiven() {
    XCTAssertEqual(
      LocationTrackingPlan.step(wantsTracking: true, status: .authorizedWhenInUse),
      .start
    )
    XCTAssertEqual(
      LocationTrackingPlan.step(wantsTracking: true, status: .authorizedAlways),
      .start
    )
  }

  func testStopsWhenPermissionIsRefused() {
    XCTAssertEqual(LocationTrackingPlan.step(wantsTracking: true, status: .denied), .stop)
    XCTAssertEqual(LocationTrackingPlan.step(wantsTracking: true, status: .restricted), .stop)
  }

  func testNeverStartsOrAsksWhenSharingIsOff() {
    for status in allStatuses {
      XCTAssertEqual(LocationTrackingPlan.step(wantsTracking: false, status: status), .stop)
    }
  }

  func testSettingsHintOnlyWhenSharingIsOnAndPermissionRefused() {
    XCTAssertTrue(LocationTrackingPlan.needsSettingsHint(wantsTracking: true, status: .denied))
    XCTAssertTrue(LocationTrackingPlan.needsSettingsHint(wantsTracking: true, status: .restricted))

    XCTAssertFalse(LocationTrackingPlan.needsSettingsHint(wantsTracking: true, status: .notDetermined))
    XCTAssertFalse(LocationTrackingPlan.needsSettingsHint(wantsTracking: true, status: .authorizedWhenInUse))
    XCTAssertFalse(LocationTrackingPlan.needsSettingsHint(wantsTracking: true, status: .authorizedAlways))

    for status in allStatuses {
      XCTAssertFalse(LocationTrackingPlan.needsSettingsHint(wantsTracking: false, status: status))
    }
  }
}
