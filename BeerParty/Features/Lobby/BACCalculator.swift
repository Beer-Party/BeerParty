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
    let hasAnyDrinks = !drinks.isEmpty

    let allDrinkTimes = drinks.map(\.consumedAt)
    let startTime = allDrinkTimes.min() ?? timestamp

    for member in sortedMembers {
      let memberDrinks = drinks.filter { $0.userId == member.userId }.sorted { $0.consumedAt < $1.consumedAt }
      let params = paramsByUserId[member.userId]
      let simulation = simulateTimeline(
        params: params,
        drinks: memberDrinks,
        start: startTime,
        end: timestamp,
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
            nickname: member.nickname,
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

  // Simulates BAC over time using absorption and elimination at fixed time steps.
  static func simulateTimeline(
    params: LobbyBACParamsData?,
    drinks: [LobbyDrink],
    start: Date,
    end: Date,
    stepMinutes: Int
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
  let nickname: String
  let time: Date
  let bac: Double
}

struct BacSnapshot {
  let current: [MemberBACSnapshot]
  let points: [BACPoint]
  let maxY: Double
}
