import Foundation

/// One row of `lobby_events` as the app uses it.
struct LobbyEventRecord: Identifiable, Equatable {
  let id: UUID
  let kind: LobbyEventKind
  /// Who caused it. Set by the database, not by the sender.
  let userId: UUID
  /// Only for "motion due".
  let motionId: UUID?
  /// The database's clock, not a phone's.
  let createdAt: Date
}

/// A row of `lobby_events` as the server sends it: exactly the columns of
/// `LobbyEventRow.columns`.
struct LobbyEventRow: Decodable {
  static let columns = "id,kind,user_id,motion_id,created_at"

  let id: UUID
  let kind: String
  let userId: UUID
  let motionId: UUID?
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case kind
    case userId = "user_id"
    case motionId = "motion_id"
    case createdAt = "created_at"
  }

  /// Nil for a kind this version does not know (a later version may add
  /// some) or a time that cannot be read; such a row is skipped.
  var record: LobbyEventRecord? {
    guard let eventKind = LobbyEventKind(rawValue: kind),
          let time = LobbyEventFeed.parseTimestamp(createdAt) else {
      return nil
    }
    return LobbyEventRecord(id: id, kind: eventKind, userId: userId, motionId: motionId, createdAt: time)
  }
}

/// "Made it home", "lobby closed" or "motion due", whichever way it reached
/// this phone: as a prefixed row in `drinks` (the old way, still written so
/// that phones on older versions see it), as a row in `lobby_events`, or both.
struct LobbyNotice: Equatable {
  let kind: LobbyEventKind
  let userId: UUID
  var motionId: UUID?
  /// The event's time (the server's clock) once the event has been seen;
  /// until then the time in the prefixed row (the sending phone's clock).
  var at: Date
  /// The nickname a "made it home" prefixed row carries.
  var nickname: String?
  /// The destination a "motion due" prefixed row carries.
  var targetText: String?
  /// The prefixed row in `drinks` this was read from, if any.
  var drinkRowId: UUID?
  /// The row in `lobby_events` this was read from, if any.
  var eventId: UUID?
}

/// What the lobby screen says when something new has happened.
enum LobbyAnnouncement: Equatable {
  case lobbyClosed(at: Date)
  case motionDue(target: String)
  case madeItHome(nickname: String)
}

/// Puts the two sources of system events together (backlog B5 step 3b).
/// No UI, no network.
enum LobbyEventFeed {
  /// How far apart a "made it home" prefixed row and its event may be and
  /// still count as the same tap. The two are written within a second of
  /// each other, but the row carries the phone's clock and the event the
  /// server's, and a phone's clock can be off by minutes.
  static let twinWindow: TimeInterval = 10 * 60

  // MARK: reading the two sources

  /// The system events among rows of `drinks`. Real drinks are left out.
  static func notices(fromDrinkRows drinks: [LobbyDrink]) -> [LobbyNotice] {
    drinks.compactMap { drink in
      if let closedAt = LobbySystemEvent.closedAtTime(from: drink) {
        return LobbyNotice(
          kind: .lobbyClosed, userId: drink.userId, motionId: nil, at: closedAt,
          nickname: nil, targetText: nil, drinkRowId: drink.id, eventId: nil
        )
      }
      if let target = LobbySystemEvent.motionArrivalTarget(from: drink) {
        return LobbyNotice(
          kind: .motionDue, userId: drink.userId, motionId: motionID(fromDrinkRow: drink), at: drink.consumedAt,
          nickname: nil, targetText: target, drinkRowId: drink.id, eventId: nil
        )
      }
      if let nickname = LobbySystemEvent.madeItHomeNickname(from: drink) {
        return LobbyNotice(
          kind: .madeItHome, userId: drink.userId, motionId: nil, at: drink.consumedAt,
          nickname: nickname, targetText: nil, drinkRowId: drink.id, eventId: nil
        )
      }
      return nil
    }
  }

  static func notices(fromEvents events: [LobbyEventRecord]) -> [LobbyNotice] {
    events.map { event in
      LobbyNotice(
        kind: event.kind, userId: event.userId, motionId: event.motionId, at: event.createdAt,
        nickname: nil, targetText: nil, drinkRowId: nil, eventId: event.id
      )
    }
  }

  /// The motion id in a "motion due" prefixed row ("<prefix><motion id>|<target>").
  static func motionID(fromDrinkRow drink: LobbyDrink) -> UUID? {
    guard drink.name.hasPrefix(LobbyBackendService.motionArrivedDrinkPrefix) else { return nil }
    let raw = drink.name.dropFirst(LobbyBackendService.motionArrivedDrinkPrefix.count)
    guard let idText = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).first else {
      return nil
    }
    return UUID(uuidString: String(idText))
  }

  // MARK: merging

  /// Adds newly read notices to the ones already known, without doubles.
  /// `all` is the new list; `fresh` are the ones that were not known in any
  /// form before, which are the ones to announce.
  ///
  /// This version of the app writes every event twice, as a prefixed row and
  /// as an event, and the two can arrive in the same poll or in different
  /// ones, in either order. The rule:
  /// - A row that was read before (same drink row or same event row) is
  ///   skipped.
  /// - A prefixed row and an event are the same thing ("twins") when they are
  ///   of the same kind and: for "lobby closed", always (a lobby closes
  ///   once); for "motion due", they name the same motion; for "made it
  ///   home", they are from the same member and at most `twinWindow` apart.
  /// - Each row has at most one twin, the nearest in time, and two rows from
  ///   the same source are never twins. So two real "made it home" taps by
  ///   one member, each written twice, stay two notices.
  /// A twin fills in what the known notice lacked and takes over the event's
  /// time; it is not announced again.
  static func merge(
    known: [LobbyNotice],
    incoming: [LobbyNotice]
  ) -> (all: [LobbyNotice], fresh: [LobbyNotice]) {
    var all = known
    var freshIndices: [Int] = []

    for notice in incoming {
      if all.contains(where: { isSameRow($0, notice) }) {
        continue
      }

      if let twinIndex = nearestTwinIndex(of: notice, in: all) {
        var twin = all[twinIndex]
        if let eventId = notice.eventId {
          twin.eventId = eventId
          twin.at = notice.at
        }
        if let drinkRowId = notice.drinkRowId {
          twin.drinkRowId = drinkRowId
        }
        twin.motionId = twin.motionId ?? notice.motionId
        twin.nickname = twin.nickname ?? notice.nickname
        twin.targetText = twin.targetText ?? notice.targetText
        all[twinIndex] = twin
      } else {
        all.append(notice)
        freshIndices.append(all.count - 1)
      }
    }

    return (all, freshIndices.map { all[$0] })
  }

  private static func isSameRow(_ known: LobbyNotice, _ incoming: LobbyNotice) -> Bool {
    if let drinkRowId = incoming.drinkRowId, known.drinkRowId == drinkRowId { return true }
    if let eventId = incoming.eventId, known.eventId == eventId { return true }
    return false
  }

  private static func nearestTwinIndex(of notice: LobbyNotice, in all: [LobbyNotice]) -> Int? {
    var best: (index: Int, distance: TimeInterval)?
    for (index, candidate) in all.enumerated() where isTwin(candidate, notice) {
      let distance = abs(candidate.at.timeIntervalSince(notice.at))
      if best == nil || distance < (best?.distance ?? .infinity) {
        best = (index, distance)
      }
    }
    return best?.index
  }

  /// `incoming` comes from one source; `known` is its twin when it is the
  /// same thing and has not been seen from that source yet.
  private static func isTwin(_ known: LobbyNotice, _ incoming: LobbyNotice) -> Bool {
    guard known.kind == incoming.kind else { return false }
    if incoming.eventId != nil {
      guard known.eventId == nil else { return false }
    } else {
      guard known.drinkRowId == nil else { return false }
    }

    switch incoming.kind {
    case .lobbyClosed:
      return true
    case .motionDue:
      guard let knownMotion = known.motionId, let incomingMotion = incoming.motionId else { return false }
      return knownMotion == incomingMotion
    case .madeItHome:
      return known.userId == incoming.userId
        && abs(known.at.timeIntervalSince(incoming.at)) <= twinWindow
    }
  }

  // MARK: using the merged list

  /// When the lobby was closed, as far as the notices say; nil when none does.
  static func closedAt(in notices: [LobbyNotice]) -> Date? {
    notices.filter { $0.kind == .lobbyClosed }.map(\.at).max()
  }

  /// The time of the newest event row seen so far: the next poll asks only
  /// for events after it. Nil while no event row has been seen.
  static func eventCursor(in notices: [LobbyNotice]) -> Date? {
    notices.filter { $0.eventId != nil }.map(\.at).max()
  }

  /// The one thing to say about a batch of new notices, as before: the lobby
  /// closing comes first, then a motion that is due, then somebody getting
  /// home; of several of a kind, the latest.
  ///
  /// An event row carries no text, so the nickname and the motion's
  /// destination are looked up in what the lobby screen has loaded. The text
  /// of a prefixed row is only used when that finds nothing.
  static func announcement(
    for fresh: [LobbyNotice],
    nickname: (UUID) -> String?,
    motionTarget: (UUID) -> String?
  ) -> LobbyAnnouncement? {
    if let closedAt = closedAt(in: fresh) {
      return .lobbyClosed(at: closedAt)
    }
    if let due = latest(of: .motionDue, in: fresh) {
      let target = nonEmpty(due.motionId.flatMap(motionTarget)) ?? nonEmpty(due.targetText) ?? "the destination"
      return .motionDue(target: target)
    }
    if let home = latest(of: .madeItHome, in: fresh) {
      let name = nonEmpty(nickname(home.userId)) ?? nonEmpty(home.nickname) ?? "Member"
      return .madeItHome(nickname: name)
    }
    return nil
  }

  private static func latest(of kind: LobbyEventKind, in notices: [LobbyNotice]) -> LobbyNotice? {
    notices.filter { $0.kind == kind }.max { $0.at < $1.at }
  }

  private static func nonEmpty(_ text: String?) -> String? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
      return nil
    }
    return trimmed
  }

  // MARK: timestamps

  /// Reads a `timestamptz` as the server sends it, with or without fractions
  /// of a second.
  static func parseTimestamp(_ raw: String) -> Date? {
    let withFractions = ISO8601DateFormatter()
    withFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = withFractions.date(from: raw) {
      return parsed
    }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: raw)
  }

  /// A time in the form the server compares `created_at` with.
  static func timestampText(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}
