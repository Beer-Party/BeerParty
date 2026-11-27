import XCTest
@testable import BeerParty

@MainActor
final class LobbyEventRequestTests: XCTestCase {

  private let lobbyID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
  private let motionID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

  /// The request as the JSON object that is sent to the database.
  private func json(_ request: LobbyEventRequest) throws -> [String: String] {
    let data = try JSONEncoder().encode(request)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
  }

  func testMadeItHomeSendsLobbyAndKindOnly() throws {
    XCTAssertEqual(
      try json(.madeItHome(lobbyID: lobbyID)),
      ["lobby_id": lobbyID.uuidString, "kind": "made_it_home"]
    )
  }

  func testLobbyClosedSendsLobbyAndKindOnly() throws {
    XCTAssertEqual(
      try json(.lobbyClosed(lobbyID: lobbyID)),
      ["lobby_id": lobbyID.uuidString, "kind": "lobby_closed"]
    )
  }

  func testMotionDueSendsTheMotionToo() throws {
    XCTAssertEqual(
      try json(.motionDue(lobbyID: lobbyID, motionID: motionID)),
      [
        "lobby_id": lobbyID.uuidString,
        "kind": "motion_due",
        "motion_id": motionID.uuidString
      ]
    )
  }

  // The table's check: a motion id on `motion_due` and on nothing else.
  func testOnlyMotionDueCarriesAMotion() {
    XCTAssertNil(LobbyEventRequest.madeItHome(lobbyID: lobbyID).motionId)
    XCTAssertNil(LobbyEventRequest.lobbyClosed(lobbyID: lobbyID).motionId)
    XCTAssertEqual(
      LobbyEventRequest.motionDue(lobbyID: lobbyID, motionID: motionID).motionId,
      motionID
    )
  }

  // No user and no time in the row: the database sets both itself.
  func testNeverSendsUserOrTime() throws {
    let keys = Set(try json(.motionDue(lobbyID: lobbyID, motionID: motionID)).keys)
    XCTAssertEqual(keys, ["lobby_id", "kind", "motion_id"])
  }
}
