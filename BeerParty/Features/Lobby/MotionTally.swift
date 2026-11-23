import Foundation

/// The rules for deciding a motion ("let's go to ...") on this phone: when
/// voting is over, whether it passed, and when to announce that it is time.
/// Plain functions with no UI, moved out of `LobbyView`.
enum MotionTally {
  /// A motion passes with more than this share of all members voting aye.
  static let passingShare = 2.0 / 3.0

  /// How long voting stays open at most.
  static let longestVotingWindow: TimeInterval = 10 * 60

  /// When voting on a new motion closes: after ten minutes, or at the motion's
  /// own time when that comes first. A motion "in 5 min" is then decided, and
  /// announced, at its time and not five minutes late.
  static func votingClosesAt(createdAt: Date, targetAt: Date) -> Date {
    let latest = createdAt.addingTimeInterval(longestVotingWindow)
    // A target in the past (a clock oddity) closes voting at once, not before
    // the motion was made.
    return max(createdAt, min(latest, targetAt))
  }

  /// nil while voting is still open. Otherwise true when the motion passed.
  ///
  /// Voting is over when every member has voted or the voting time has run out.
  /// The share is of all members, so a member who did not vote counts against.
  /// A lobby with no known members is counted as one member.
  static func outcome(
    ayeCount: Int,
    voteCount: Int,
    memberCount: Int,
    votingClosesAt: Date,
    now: Date
  ) -> Bool? {
    let members = max(1, memberCount)
    let allVoted = voteCount >= members
    let voteWindowExpired = now >= votingClosesAt
    guard allVoted || voteWindowExpired else { return nil }

    return (Double(ayeCount) / Double(members)) > passingShare
  }

  /// True when a decided motion passed, its time has come and nobody has
  /// announced it yet.
  static func shouldAnnounceArrival(
    passed: Bool?,
    targetAt: Date,
    notifiedAt: Date?,
    now: Date
  ) -> Bool {
    passed == true && targetAt <= now && notifiedAt == nil
  }
}
