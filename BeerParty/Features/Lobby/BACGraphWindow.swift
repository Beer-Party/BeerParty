import Foundation

/// What the intoxication graph draws: the points inside the visible time window,
/// the newest point per member (for the name labels) and the axis ranges.
struct BacGraphDisplayData {
  let points: [BACPoint]
  let latestPointByMember: [UUID: BACPoint]
  let xDomain: ClosedRange<Date>
  let maxY: Double
  let baseDuration: TimeInterval?
  let visibleDuration: TimeInterval?
}

/// Picks the part of a BAC snapshot the graph shows. No UI, no network.
enum BACGraphWindow {
  /// Pinching in never shows less than this.
  static let minimumVisibleDuration: TimeInterval = 20 * 60

  /// - Parameters:
  ///   - timeframeDuration: length of the selected timeframe (2h, 5h), or nil for "All".
  ///   - customVisibleDuration: length chosen by pinching, or nil when not zoomed.
  static func displayData(
    snapshot: BacSnapshot,
    now: Date,
    timeframeDuration: TimeInterval?,
    customVisibleDuration: TimeInterval?
  ) -> BacGraphDisplayData {
    guard let earliestTime = snapshot.points.map(\.time).min(),
          let latestTime = snapshot.points.map(\.time).max() else {
      return BacGraphDisplayData(
        points: [],
        latestPointByMember: [:],
        xDomain: now...now,
        maxY: snapshot.maxY,
        baseDuration: nil,
        visibleDuration: nil
      )
    }

    let baseStart: Date
    if let duration = timeframeDuration {
      baseStart = max(earliestTime, latestTime.addingTimeInterval(-duration))
    } else {
      baseStart = earliestTime
    }

    let baseDomain = baseStart...latestTime
    let baseDuration = max(baseDomain.upperBound.timeIntervalSince(baseDomain.lowerBound), 60)
    let currentDuration = max(
      minimumVisibleDuration,
      min(baseDuration, customVisibleDuration ?? baseDuration)
    )
    let visibleStart = max(baseDomain.lowerBound, baseDomain.upperBound.addingTimeInterval(-currentDuration))
    let visibleDomain = visibleStart...baseDomain.upperBound

    let filteredPoints = snapshot.points.filter { visibleDomain.contains($0.time) }
    let latestPointByMember = Dictionary(
      grouping: filteredPoints,
      by: \.userId
    ).compactMapValues { memberPoints in
      memberPoints.max { $0.time < $1.time }
    }

    let visibleMaxY = max(
      0.05,
      filteredPoints.map(\.bac).max() ?? snapshot.maxY
    )

    return BacGraphDisplayData(
      points: filteredPoints,
      latestPointByMember: latestPointByMember,
      xDomain: visibleDomain,
      maxY: visibleMaxY,
      baseDuration: baseDuration,
      visibleDuration: currentDuration
    )
  }
}
