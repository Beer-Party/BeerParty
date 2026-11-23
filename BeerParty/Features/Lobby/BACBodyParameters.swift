import Foundation

/// The four profile columns the BAC parameters are worked out from. The query
/// asks for exactly these, so this type must not require any other column:
/// decoding the answer as `UserProfile` failed every time, because that type
/// also needs the two location-sharing columns.
struct BACProfileFields: Decodable, Equatable {
  let id: UUID
  /// Stored in pounds, as `ProfileSetupView` saves it.
  let weight: Double
  let age: Int
  let gender: String
}

/// Body water and elimination rate for the BAC maths, worked out from the
/// user's profile. Plain functions with no network or UI.
enum BACBodyParameters {
  /// Used only when the profile cannot be read.
  static let fallbackTBW = 40.0
  static let fallbackEliminationPerHourPromille = 0.14

  static func fallback(userID: UUID) -> LobbyBACParamsData {
    LobbyBACParamsData(
      userId: userID,
      tbw: fallbackTBW,
      eliminationPerHourPromille: fallbackEliminationPerHourPromille
    )
  }

  /// Total body water (Watson-style formulas) and elimination rate.
  static func derive(from profile: BACProfileFields) -> LobbyBACParamsData {
    let weightKg = max(40, profile.weight / 2.20462)
    let age = max(18, profile.age)
    let gender = profile.gender.lowercased()

    // "female" contains "male", so it has to be checked first.
    if gender.contains("female") {
      return LobbyBACParamsData(
        userId: profile.id,
        tbw: max(20, 14.46 + 0.2549 * weightKg),
        eliminationPerHourPromille: 0.15
      )
    }
    if gender.contains("male") {
      return LobbyBACParamsData(
        userId: profile.id,
        tbw: max(20, 20.03 - 0.1183 * Double(age) + 0.3626 * weightKg),
        eliminationPerHourPromille: 0.13
      )
    }
    return LobbyBACParamsData(
      userId: profile.id,
      tbw: max(20, 17.25 + 0.308 * weightKg),
      eliminationPerHourPromille: 0.14
    )
  }

  /// True when the row saved for a lobby has to be written (again): there is no
  /// row, a value is missing, or the values differ from what the profile gives
  /// now (the fallback saved by older versions, or a weight changed since).
  static func needsSaving(
    savedTBW: Double?,
    savedEliminationPerHourPromille: Double?,
    derived: LobbyBACParamsData
  ) -> Bool {
    guard let savedTBW, let savedEliminationPerHourPromille else { return true }
    let tolerance = 0.0005
    return abs(savedTBW - derived.tbw) > tolerance
      || abs(savedEliminationPerHourPromille - derived.eliminationPerHourPromille) > tolerance
  }
}
