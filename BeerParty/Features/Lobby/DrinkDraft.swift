import Foundation

/// What is typed into a drink form: the "Add Drink" section and the "Edit Drink"
/// sheet. Holds the three texts and answers whether they make a drink that can
/// be saved. No UI, no network.
struct DrinkDraft: Equatable {
  var name: String = ""
  var volumeText: String = ""
  var abvText: String = ""

  init(name: String = "", volumeText: String = "", abvText: String = "") {
    self.name = name
    self.volumeText = volumeText
    self.abvText = abvText
  }

  /// The form filled in with a drink that is about to be edited.
  init(editing drink: LobbyDrink) {
    self.init(
      name: drink.name,
      volumeText: String(format: "%.0f", drink.volumeMl),
      abvText: String(format: "%.1f", drink.abv)
    )
  }

  var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// The typed volume, or nil when it is not a number above zero.
  var volumeMl: Double? {
    guard let parsed = DecimalInput.parse(volumeText), parsed > 0 else { return nil }
    return parsed
  }

  /// The typed ABV, or nil when it is not a number. Zero is allowed (water).
  var abv: Double? {
    guard let parsed = DecimalInput.parse(abvText), parsed >= 0 else { return nil }
    return parsed
  }

  /// True when there is a name, a volume and an ABV.
  var isComplete: Bool {
    !trimmedName.isEmpty && volumeMl != nil && abv != nil
  }

  /// Why the typed volume or ABV is too large, or nil when it is fine.
  var limitMessage: String? {
    DrinkInputLimits.message(volumeMl: volumeMl, abv: abv)
  }

  /// True when the button that saves the drink should be enabled.
  var canSubmit: Bool {
    isComplete && limitMessage == nil
  }
}
