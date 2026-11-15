import XCTest
@testable import BeerParty

@MainActor
final class ClearedLocationValuesTests: XCTestCase {

  // Clearing a location only works if lat and lng reach the server as JSON nulls.
  // If they are left out of the body, the old coordinates stay in the table.
  func testClearedLocationSendsExplicitNulls() throws {
    let values = LobbyBackendService.clearedLocationValues(at: Date(timeIntervalSince1970: 1_800_000_000))
    let data = try JSONEncoder().encode(values)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

    XCTAssertEqual(Set(object.keys), ["lat", "lng", "updated_at"])
    XCTAssertTrue(object["lat"] is NSNull)
    XCTAssertTrue(object["lng"] is NSNull)
    XCTAssertEqual(object["updated_at"] as? String, "2027-01-15T08:00:00.000Z")
  }

  // The request type used for normal location writes drops nil values, which is
  // why it must not be used to clear a location.
  func testLocationUpsertRequestOmitsNilCoordinates() throws {
    let request = UpdateMemberLocationRequest(
      lobbyId: UUID(),
      userId: UUID(),
      lat: nil,
      lng: nil,
      updatedAt: Date()
    )
    let data = try JSONEncoder().encode(request)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

    XCTAssertNil(object["lat"])
    XCTAssertNil(object["lng"])
  }
}
