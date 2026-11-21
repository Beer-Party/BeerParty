import CoreLocation

/// What the location service should do next, given whether the user has
/// location sharing switched on and what iOS says about permission.
enum LocationTrackingStep: Equatable {
  /// Permission was never asked for: show the system prompt.
  case askPermission
  /// Permission is given: start location updates.
  case start
  /// Sharing is off, or permission is refused: stop location updates.
  case stop
}

enum LocationTrackingPlan {
  static func step(wantsTracking: Bool, status: CLAuthorizationStatus) -> LocationTrackingStep {
    guard wantsTracking else { return .stop }

    switch status {
    case .notDetermined:
      return .askPermission
    case .authorizedWhenInUse, .authorizedAlways:
      return .start
    case .restricted, .denied:
      return .stop
    @unknown default:
      return .stop
    }
  }

  /// True when sharing is switched on but iOS will not give a location, so the
  /// screen should say where to change that.
  static func needsSettingsHint(wantsTracking: Bool, status: CLAuthorizationStatus) -> Bool {
    guard wantsTracking else { return false }
    return status == .denied || status == .restricted
  }

  static let settingsHint =
    "Location access is off for BeerParty. Allow it in the Settings app (BeerParty > Location) to share your location."
}
