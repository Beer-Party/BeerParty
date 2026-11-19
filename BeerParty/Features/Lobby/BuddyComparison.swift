import Foundation

/// How the current user's BAC compares with one other member's, for the
/// "buddy" section of the lobby screen.
struct BuddyComparisonData: Equatable {
  let buddyNickname: String
  let bacGap: Double
  let standardBeerGap: Double
  let isAhead: Bool

  var isEven: Bool {
    bacGap < 0.01
  }
}

enum BuddyComparison {
  /// Grams of alcohol in a standard beer: 330 ml at 5 %, ethanol at 0.789 g/ml.
  static let standardBeerGrams = 330.0 * 0.05 * 0.789

  /// Compares the current user with the chosen buddy. Returns nil when no buddy
  /// is chosen or either of the two is missing from the snapshot.
  ///
  /// The gap in standard beers is how many beers would move the current user's
  /// own BAC by the gap, so it uses the current user's body-water value.
  static func compare(
    current: [MemberBACSnapshot],
    currentUserID: UUID,
    buddyID: UUID?,
    currentUserParams: LobbyBACParamsData?
  ) -> BuddyComparisonData? {
    guard let buddyID,
          let me = current.first(where: { $0.userId == currentUserID }),
          let buddy = current.first(where: { $0.userId == buddyID }) else {
      return nil
    }

    let bacGapSigned = me.bac - buddy.bac
    let bacGap = abs(bacGapSigned)
    let parameters = BACCalculator.parameters(for: currentUserParams)
    let alcoholGramsGap = bacGap * parameters.tbw / 0.84
    let standardBeerGap = alcoholGramsGap / standardBeerGrams

    return BuddyComparisonData(
      buddyNickname: buddy.nickname,
      bacGap: bacGap,
      standardBeerGap: standardBeerGap,
      isAhead: bacGapSigned >= 0
    )
  }
}
