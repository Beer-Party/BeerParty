import Foundation

/// Reads a number typed on the decimal keypad. The keypad shows a comma in most
/// European regions and a point elsewhere, and `Double("4,7")` is nil, so both
/// separators are accepted here whatever the phone's region is.
enum DecimalInput {
  private static let allowedDigits = Set("0123456789")

  /// Returns the number, or nil when the text is not a plain decimal number
  /// (empty, letters, a sign, or more than one separator such as "1,234.5").
  static func parse(_ text: String) -> Double? {
    let normalized = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: ",", with: ".")
    let digits = normalized.filter { $0 != "." }
    let separatorCount = normalized.count - digits.count
    guard !digits.isEmpty,
          separatorCount <= 1,
          digits.allSatisfy({ allowedDigits.contains($0) }) else {
      return nil
    }
    return Double(normalized)
  }
}
