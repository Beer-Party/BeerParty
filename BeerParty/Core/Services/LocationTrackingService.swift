import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationTrackingService: NSObject, ObservableObject {
  @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
  @Published private(set) var lastLocation: CLLocation?

  var onLocationUpdate: ((CLLocation) -> Void)?

  private let manager = CLLocationManager()
  // True from startTracking until stopTracking: the user wants updates, whether or
  // not permission has been given yet.
  private var wantsTracking = false
  private var wantsBackground = false

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    manager.distanceFilter = 25
    manager.pausesLocationUpdatesAutomatically = true
    authorizationStatus = manager.authorizationStatus
  }

  func startTracking(allowsBackground: Bool) {
    manager.allowsBackgroundLocationUpdates = allowsBackground
    wantsTracking = true
    wantsBackground = allowsBackground
    applyTrackingPlan(mayAskPermission: true)
  }

  func stopTracking() {
    manager.stopUpdatingLocation()
    wantsTracking = false
  }

  // Starts or stops updates for the current permission. The permission callback
  // calls this too, so updates begin as soon as the user taps "Allow".
  private func applyTrackingPlan(mayAskPermission: Bool) {
    let status = manager.authorizationStatus
    switch LocationTrackingPlan.step(wantsTracking: wantsTracking, status: status) {
    case .askPermission:
      if mayAskPermission {
        manager.requestWhenInUseAuthorization()
      }
    case .start:
      if mayAskPermission, wantsBackground, status == .authorizedWhenInUse {
        manager.requestAlwaysAuthorization()
      }
      manager.startUpdatingLocation()
    case .stop:
      // Keeps wantsTracking, so sharing resumes if permission is given later in
      // Settings while the toggle is still on.
      manager.stopUpdatingLocation()
    }
  }
}

extension LocationTrackingService: CLLocationManagerDelegate {
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor in
      authorizationStatus = manager.authorizationStatus
      if wantsTracking {
        applyTrackingPlan(mayAskPermission: false)
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let latest = locations.last else { return }
    Task { @MainActor in
      lastLocation = latest
      onLocationUpdate?(latest)
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // Keep silent for transient location errors to avoid noisy UI.
  }
}
