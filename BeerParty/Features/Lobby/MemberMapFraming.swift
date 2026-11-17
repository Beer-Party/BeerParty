import MapKit

/// Works out which part of the map to show so that every member is in view.
enum MemberMapFraming {
  /// Never zoom in further than this (about 2 km), even for a single member or
  /// for members standing next to each other.
  static let minimumSpanDegrees = 0.02

  /// Extra room around the outermost members, so their pins are not on the edge.
  static let paddingFactor = 1.4

  /// The region that contains all the coordinates, or nil when there are none.
  /// Members on both sides of the 180° meridian are not handled specially; the
  /// map then shows the long way round.
  static func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
    let valid = coordinates.filter { CLLocationCoordinate2DIsValid($0) }
    guard let first = valid.first else { return nil }

    var minLat = first.latitude
    var maxLat = first.latitude
    var minLng = first.longitude
    var maxLng = first.longitude
    for coordinate in valid.dropFirst() {
      minLat = min(minLat, coordinate.latitude)
      maxLat = max(maxLat, coordinate.latitude)
      minLng = min(minLng, coordinate.longitude)
      maxLng = max(maxLng, coordinate.longitude)
    }

    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLng + maxLng) / 2
      ),
      span: MKCoordinateSpan(
        latitudeDelta: min(180, max(minimumSpanDegrees, (maxLat - minLat) * paddingFactor)),
        longitudeDelta: min(360, max(minimumSpanDegrees, (maxLng - minLng) * paddingFactor))
      )
    )
  }
}
