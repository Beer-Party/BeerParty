import Foundation

extension QuickAddDrinkPreset {
  /// The Lock Screen "custom" button made from a manually added drink.
  /// nil when the name is empty, so a button with no name is never saved (a
  /// drink added with it would have an empty name in the drink history).
  static func custom(name: String, volumeMl: Double, abv: Double) -> QuickAddDrinkPreset? {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return nil }
    return QuickAddDrinkPreset(id: "custom", name: trimmedName, volumeMl: volumeMl, abv: abv)
  }
}
