import Foundation

/// Limits for the weight and age typed into the profile. A slip such as 750
/// instead of 75 kg would otherwise be saved and make that member's BAC about
/// ten times too low on every phone in the lobby. No UI, no network.
///
/// There is no minimum age here: that is a decision for the owners.
enum ProfileInputLimits {
  static let minWeightKg: Double = 30
  static let maxWeightKg: Double = 300
  /// The same range in whole pounds (30 kg is 66.1 lbs, 300 kg is 661.4 lbs).
  static let minWeightLbs: Double = 66
  static let maxWeightLbs: Double = 661
  static let maxAge = 120

  static let kilogramsMessage = "Weight must be between 30 and 300 kg."
  static let poundsMessage = "Weight must be between 66 and 661 lbs."
  static let ageLimitMessage = "Age can be at most 120."

  /// What is wrong with the weight as typed, in the unit shown, or nil when it
  /// is within the limits. A weight that is nil (nothing typed yet, or not a
  /// number) or not above zero is not judged here: the Save button is already
  /// off for it.
  static func weightMessage(entered: Double?, inKilograms: Bool) -> String? {
    guard let entered, entered > 0 else { return nil }
    if inKilograms {
      return (minWeightKg...maxWeightKg).contains(entered) ? nil : kilogramsMessage
    }
    return (minWeightLbs...maxWeightLbs).contains(entered) ? nil : poundsMessage
  }

  /// nil when the age is within the limit, or not judged (nil or not above
  /// zero, as for the weight).
  static func ageMessage(age: Int?) -> String? {
    guard let age, age > maxAge else { return nil }
    return ageLimitMessage
  }

  static func allows(enteredWeight: Double?, inKilograms: Bool, age: Int?) -> Bool {
    weightMessage(entered: enteredWeight, inKilograms: inKilograms) == nil
      && ageMessage(age: age) == nil
  }
}
