import Foundation

/// The BAC model: how much of each drink has been absorbed, how fast it is
/// eliminated, and the resulting curve for every lobby member. No UI, no network.
enum BACCalculator {
  // Builds current BAC values and timeline points for every member.
  static func snapshot(
    members: [LobbyMemberData],
    drinks: [LobbyDrink],
    paramsByUserId: [UUID: LobbyBACParamsData],
    at timestamp: Date
  ) -> BacSnapshot {
    let sortedMembers = members.sorted {
      $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
    }
    var current: [MemberBACSnapshot] = []
    var points: [BACPoint] = []
    let seriesLabels = BACSeriesLabels.labels(for: members)
    let hasAnyDrinks = !drinks.isEmpty

    let allDrinkTimes = drinks.map(\.consumedAt)
    let startTime = allDrinkTimes.min() ?? timestamp
    // A lobby from last week is not simulated up to today: the timeline stops
    // where everybody is back at zero.
    let endTime = timelineEnd(
      members: members,
      drinks: drinks,
      paramsByUserId: paramsByUserId,
      now: timestamp
    )

    for member in sortedMembers {
      let memberDrinks = drinks.filter { $0.userId == member.userId }.sorted { $0.consumedAt < $1.consumedAt }
      let params = paramsByUserId[member.userId]
      let simulation = simulateTimeline(
        params: params,
        drinks: memberDrinks,
        start: startTime,
        end: endTime,
        stepMinutes: 10
      )

      current.append(
        MemberBACSnapshot(
          userId: member.userId,
          nickname: member.nickname,
          bac: simulation.currentBAC
        )
      )

      if hasAnyDrinks {
        points.append(contentsOf: simulation.points.map {
          BACPoint(
            id: "\(member.userId.uuidString)-\($0.time.timeIntervalSince1970)",
            userId: member.userId,
            nickname: member.nickname,
            label: seriesLabels[member.userId] ?? member.nickname,
            time: $0.time,
            bac: $0.bac
          )
        })
      }
    }

    let maxY = max(0.05, points.map(\.bac).max() ?? 0.05)
    let sortedCurrent = current.sorted { lhs, rhs in
      if lhs.bac == rhs.bac {
        return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
      }
      return lhs.bac > rhs.bac
    }
    return BacSnapshot(current: sortedCurrent, points: points, maxY: maxY)
  }

  /// Where the timeline (and so the graph) ends: the first 10-minute step at
  /// which every member has absorbed all their drinks and is back at zero, and
  /// never later than `now`. After that moment nothing changes any more, so
  /// everybody's BAC at `now` is zero as well.
  static func timelineEnd(
    members: [LobbyMemberData],
    drinks: [LobbyDrink],
    paramsByUserId: [UUID: LobbyBACParamsData],
    now: Date,
    stepMinutes: Int = 10
  ) -> Date {
    guard let startTime = drinks.map(\.consumedAt).min(), startTime < now else {
      return now
    }

    var end = startTime
    for member in members {
      let memberDrinks = drinks.filter { $0.userId == member.userId }
      guard !memberDrinks.isEmpty else { continue }
      let simulation = simulateTimeline(
        params: paramsByUserId[member.userId],
        drinks: memberDrinks,
        start: startTime,
        end: now,
        stepMinutes: stepMinutes,
        stopsWhenSober: true
      )
      if let soberAt = simulation.points.last?.time, soberAt > end {
        end = soberAt
      }
      if end >= now {
        return now
      }
    }
    return end
  }

  // Simulates BAC over time using absorption and elimination at fixed time steps.
  // With `stopsWhenSober` the simulation ends early, at the first step where all
  // drinks are absorbed and no alcohol is left.
  static func simulateTimeline(
    params: LobbyBACParamsData?,
    drinks: [LobbyDrink],
    start: Date,
    end: Date,
    stepMinutes: Int,
    stopsWhenSober: Bool = false
  ) -> BACSimulationResult {
    guard end >= start else {
      return BACSimulationResult(points: [TimelineBACPoint(time: end, bac: 0)], currentBAC: 0)
    }

    let parameters = Self.parameters(for: params)
    let eliminationPerHourGrams = (parameters.eliminationPerHourPromille * parameters.tbw) / 0.84
    let sortedDrinks = drinks.sorted { $0.consumedAt < $1.consumedAt }
    let stepSeconds = TimeInterval(stepMinutes * 60)

    var points: [TimelineBACPoint] = []
    var currentTime = start
    var alcoholInBodyGrams: Double = 0

    points.append(TimelineBACPoint(time: currentTime, bac: 0))

    while currentTime < end {
      let nextTime = min(end, currentTime.addingTimeInterval(stepSeconds))
      let dtHours = nextTime.timeIntervalSince(currentTime) / 3600
      if dtHours <= 0 {
        currentTime = nextTime
        continue
      }

      var absorbedGrams: Double = 0
      for drink in sortedDrinks {
        let previousHours = currentTime.timeIntervalSince(drink.consumedAt) / 3600
        let currentHours = nextTime.timeIntervalSince(drink.consumedAt) / 3600
        let previousFraction = absorbedFraction(hoursSinceDrink: previousHours, abv: drink.abv)
        let currentFraction = absorbedFraction(hoursSinceDrink: currentHours, abv: drink.abv)
        let deltaFraction = max(0, currentFraction - previousFraction)
        absorbedGrams += drink.alcoholGrams * deltaFraction
      }

      alcoholInBodyGrams = max(
        0,
        alcoholInBodyGrams + absorbedGrams - eliminationPerHourGrams * dtHours
      )

      let currentBAC = max(0, (alcoholInBodyGrams / parameters.tbw) * 0.84)
      points.append(TimelineBACPoint(time: nextTime, bac: currentBAC))

      currentTime = nextTime

      if stopsWhenSober, alcoholInBodyGrams == 0 {
        let everythingAbsorbed = sortedDrinks.allSatisfy { drink in
          let hours = nextTime.timeIntervalSince(drink.consumedAt) / 3600
          return absorbedFraction(hoursSinceDrink: hours, abv: drink.abv) >= 1
        }
        if everythingAbsorbed {
          break
        }
      }
    }

    return BACSimulationResult(points: points, currentBAC: points.last?.bac ?? 0)
  }

  // Uses precomputed per-member BAC parameters to avoid reading raw profiles.
  static func parameters(for params: LobbyBACParamsData?) -> BACParameters {
    guard let params else {
      return BACParameters(tbw: 40, eliminationPerHourPromille: 0.14)
    }
    return BACParameters(
      tbw: max(20, params.tbw),
      eliminationPerHourPromille: max(0.08, min(0.2, params.eliminationPerHourPromille))
    )
  }

  // Returns what fraction of a drink is absorbed based on elapsed time and ABV.
  static func absorbedFraction(hoursSinceDrink: Double, abv: Double) -> Double {
    guard hoursSinceDrink > 0 else { return 0 }
    let absorptionDurationHours = min(max(1.6 - (abv * 0.03), 0.25), 1.6)
    return min(1, hoursSinceDrink / absorptionDurationHours)
  }
}

struct BACParameters {
  let tbw: Double
  let eliminationPerHourPromille: Double
}

struct TimelineBACPoint {
  let time: Date
  let bac: Double
}

struct BACSimulationResult {
  let points: [TimelineBACPoint]
  let currentBAC: Double
}

struct MemberBACSnapshot: Identifiable {
  let userId: UUID
  let nickname: String
  let bac: Double

  var id: UUID { userId }
}

struct BACPoint: Identifiable {
  let id: String
  /// Whose line the point belongs to. Lines are told apart by this, not by name.
  let userId: UUID
  let nickname: String
  /// The name shown on the graph: the nickname, or "Anna (2)" when another
  /// member has the same one (see `BACSeriesLabels`).
  let label: String
  let time: Date
  let bac: Double
}

struct BacSnapshot {
  let current: [MemberBACSnapshot]
  let points: [BACPoint]
  let maxY: Double
}
