import Foundation

/// Which unit the profile's weight field starts in, and how a saved weight is
/// shown in it. The database always holds pounds; this is only about what the
/// user sees and types. No UI, no network.
enum WeightUnitPreference {
  static let poundsPerKilogram = 2.20462

  /// Kilograms everywhere except where pounds are the everyday unit for body
  /// weight (the US and UK measurement systems).
  static func prefersKilograms(_ measurementSystem: Locale.MeasurementSystem) -> Bool {
    measurementSystem != .us && measurementSystem != .uk
  }

  /// The text for the weight field, from the weight saved in pounds: whole
  /// pounds, or kilograms with one decimal.
  static func displayText(pounds: Double, inKilograms: Bool) -> String {
    if inKilograms {
      return String(format: "%.1f", pounds / poundsPerKilogram)
    }
    return String(format: "%.0f", pounds)
  }
}
