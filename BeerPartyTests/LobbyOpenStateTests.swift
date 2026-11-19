import XCTest
@testable import BeerParty

@MainActor
final class LobbyOpenStateTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  private func timestamp(hoursAgo: Double, fractional: Bool = true) -> String {
    let formatter = ISO8601DateFormatter()
    if fractional {
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    return formatter.string(from: now.addingTimeInterval(-hoursAgo * 3600))
  }

  private func state(status: Int = 200, json: String) -> LobbyOpenState {
    LobbyOpenState.from(statusCode: status, body: Data(json.utf8), now: now)
  }

  func testActiveLobbyMadeRecentlyIsOpen() {
    let json = #"[{"is_active":true,"created_at":"\#(timestamp(hoursAgo: 3))"}]"#
    XCTAssertEqual(state(json: json), .open)
  }

  func testLobbyMarkedInactiveIsClosed() {
    let json = #"[{"is_active":false,"created_at":"\#(timestamp(hoursAgo: 3))"}]"#
    XCTAssertEqual(state(json: json), .closed)
  }

  // Nobody has opened the app since, so the row still says active.
  func testActiveLobbyOlderThanADayIsClosed() {
    let json = #"[{"is_active":true,"created_at":"\#(timestamp(hoursAgo: 25))"}]"#
    XCTAssertEqual(state(json: json), .closed)
  }

  func testTimestampWithoutFractionalSecondsIsRead() {
    let json = #"[{"is_active":true,"created_at":"\#(timestamp(hoursAgo: 25, fractional: false))"}]"#
    XCTAssertEqual(state(json: json), .closed)
  }

  func testPostgresStyleTimestampWithMicrosecondsIsRead() {
    // 2027-01-15T08:00:00Z is 1_800_000_000; this is 30 hours earlier.
    let json = #"[{"is_active":true,"created_at":"2027-01-14T02:00:00.123456+00:00"}]"#
    XCTAssertEqual(state(json: json), .closed)
  }

  func testMissingOrUnreadableCreationTimeFallsBackToTheActiveFlag() {
    XCTAssertEqual(state(json: #"[{"is_active":true}]"#), .open)
    XCTAssertEqual(state(json: #"[{"is_active":true,"created_at":null}]"#), .open)
    XCTAssertEqual(state(json: #"[{"is_active":true,"created_at":"yesterday"}]"#), .open)
  }

  // No answer must never block a drink: the insert then succeeds or fails as before.
  func testNoRowIsUnknown() {
    XCTAssertEqual(state(json: "[]"), .unknown)
  }

  func testErrorStatusIsUnknown() {
    XCTAssertEqual(state(status: 401, json: #"{"message":"JWT expired"}"#), .unknown)
    XCTAssertEqual(state(status: 500, json: #"[{"is_active":false}]"#), .unknown)
  }

  func testUnreadableBodyIsUnknown() {
    XCTAssertEqual(state(json: "not json"), .unknown)
  }
}
