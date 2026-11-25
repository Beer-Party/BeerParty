import Foundation

/// One line of the "Live BAC" list: a member, their BAC and how long their bar
/// is. No UI, no network.
struct LiveBACRow: Identifiable, Equatable {
  let userId: UUID
  let nickname: String
  let bac: Double
  let isCurrentUser: Bool
  let profilePicPath: String?
  /// Length of the bar, from 0 to 1.
  let barFraction: Double

  var id: UUID { userId }
}

/// Builds the lines of the "Live BAC" list from the BAC snapshot.
enum LiveBACRows {
  /// A full bar stands for at least this much (in ‰). Without it one beer in
  /// an otherwise sober lobby would fill the whole bar.
  static let smallestFullBar = 0.5

  /// The bars compare the members with each other: the highest BAC in the
  /// lobby gets the longest bar. They say nothing about what is safe.
  static func barFraction(bac: Double, highest: Double) -> Double {
    let fullBar = max(smallestFullBar, highest)
    guard bac.isFinite, bac > 0 else { return 0 }
    return min(1, bac / fullBar)
  }

  /// Keeps the order of `current` (highest BAC first, as the snapshot gives it).
  static func rows(
    current: [MemberBACSnapshot],
    members: [LobbyMemberData],
    currentUserID: UUID?
  ) -> [LiveBACRow] {
    let highest = current.map(\.bac).max() ?? 0
    var picPathByUserID: [UUID: String] = [:]
    for member in members {
      if let path = member.profilePicPath, !path.isEmpty {
        picPathByUserID[member.userId] = path
      }
    }

    return current.map { member in
      LiveBACRow(
        userId: member.userId,
        nickname: member.nickname,
        bac: member.bac,
        isCurrentUser: member.userId == currentUserID,
        profilePicPath: picPathByUserID[member.userId],
        barFraction: barFraction(bac: member.bac, highest: highest)
      )
    }
  }
}
