import Foundation

/// Which point of the intoxication graph a long press is pointing at.
/// No UI, no network: the view turns the finger position into a time and a BAC
/// value and asks here for the nearest point.
enum BACGraphInspection {
  /// A time difference of this many seconds counts as much as a BAC difference
  /// of the whole height of the graph.
  static let secondsPerUnit = 120.0

  /// The smallest graph height used when weighing BAC differences, so an almost
  /// flat graph does not make tiny differences decisive.
  static let minimumMaxY = 0.05

  /// The point closest to the finger, or nil when there are no points. When the
  /// finger's BAC value is unknown only the time counts. Of several points at the
  /// same distance the first one wins.
  static func nearestPoint(
    in points: [BACPoint],
    hoveredTime: Date,
    hoveredBAC: Double?,
    maxY: Double
  ) -> BACPoint? {
    points.min { lhs, rhs in
      distanceScore(
        point: lhs,
        hoveredTime: hoveredTime,
        hoveredBAC: hoveredBAC,
        maxY: maxY
      ) < distanceScore(
        point: rhs,
        hoveredTime: hoveredTime,
        hoveredBAC: hoveredBAC,
        maxY: maxY
      )
    }
  }

  /// How far a point is from the finger: the time difference in units of
  /// `secondsPerUnit` plus the BAC difference as a share of the graph's height.
  static func distanceScore(
    point: BACPoint,
    hoveredTime: Date,
    hoveredBAC: Double?,
    maxY: Double
  ) -> Double {
    let timeDistanceSeconds = abs(point.time.timeIntervalSince(hoveredTime))
    let normalizedTimeDistance = timeDistanceSeconds / secondsPerUnit
    let normalizedBacDistance: Double
    if let hoveredBAC {
      normalizedBacDistance = abs(point.bac - hoveredBAC) / max(maxY, minimumMaxY)
    } else {
      normalizedBacDistance = 0
    }
    return normalizedTimeDistance + normalizedBacDistance
  }
}
