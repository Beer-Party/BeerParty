import Foundation

/// Upper limits for a drink. A slip such as ABV 400 or 33000 ml would otherwise be
/// saved, give an absurd BAC and be synced to the whole lobby.
enum DrinkInputLimits {
  /// Two litres: more than any single serving, including a pitcher or a boot.
  static let maxVolumeMl: Double = 2000
  static let maxAbv: Double = 100

  static let volumeMessage = "Volume can be at most 2000 ml."
  static let abvMessage = "ABV can be at most 100 %."

  /// What is wrong with the values, as a sentence for the user, or nil when both
  /// are within the limits. A value that is nil (nothing typed yet, or not a
  /// number) is not judged here.
  static func message(volumeMl: Double?, abv: Double?) -> String? {
    var problems: [String] = []
    if let volumeMl, volumeMl > maxVolumeMl {
      problems.append(volumeMessage)
    }
    if let abv, abv > maxAbv {
      problems.append(abvMessage)
    }
    return problems.isEmpty ? nil : problems.joined(separator: " ")
  }

  static func allows(volumeMl: Double, abv: Double) -> Bool {
    message(volumeMl: volumeMl, abv: abv) == nil
  }
}
