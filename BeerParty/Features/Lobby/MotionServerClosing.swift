import Foundation

/// The database decides a motion, not the phone. Two things in it do that: a
/// trigger closes a motion the moment its last member votes, and the function
/// `close_expired_motions` closes the ones whose voting time has run out. The
/// function only runs when somebody calls it, so each phone calls it when one
/// of the motions it shows looks due. These are the two small decisions around
/// that call.
enum MotionServerClosing {
  /// The database function that closes motions whose voting time is over.
  static let functionName = "close_expired_motions"

  /// True when one of the motions just fetched looks finished to this phone
  /// (voting time over, or every member it knows of has voted) and is still
  /// open on the server. False nearly every time, so the usual refresh costs
  /// no extra request. The phone's own count is only the reason to ask; the
  /// result is worked out by the database.
  static func shouldAskServer(motions: [LobbyMotion], memberCount: Int, now: Date) -> Bool {
    !MotionTally.closings(for: motions, memberCount: memberCount, now: now).isEmpty
  }

  /// True when the motions have to be read again: the server closed at least
  /// one just now. `closedByServer` is nil when the server was not asked or
  /// the request failed; the next refresh then tries again.
  static func shouldFetchAgain(closedByServer: Int?) -> Bool {
    (closedByServer ?? 0) > 0
  }
}
