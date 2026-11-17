import XCTest
@testable import BeerParty

@MainActor
final class LobbyInviteTests: XCTestCase {

  func testMessageNamesTheLobbyAndTheCode() {
    XCTAssertEqual(
      LobbyInvite.shareMessage(lobbyName: "Friday", inviteCode: "HOPS"),
      "Join my BeerParty lobby \u{201C}Friday\u{201D} with invite code HOPS"
    )
  }

  func testMessageTrimsSpacesAroundNameAndCode() {
    XCTAssertEqual(
      LobbyInvite.shareMessage(lobbyName: "  Friday \n", inviteCode: " HOPS "),
      "Join my BeerParty lobby \u{201C}Friday\u{201D} with invite code HOPS"
    )
  }

  func testMessageWithoutALobbyNameStillCarriesTheCode() {
    XCTAssertEqual(
      LobbyInvite.shareMessage(lobbyName: "   ", inviteCode: "HOPS"),
      "Join my BeerParty lobby with invite code HOPS"
    )
  }

  // The code is the last word, with nothing after it, so it is easy to copy.
  func testMessageEndsWithTheCode() {
    XCTAssertTrue(LobbyInvite.shareMessage(lobbyName: "Friday", inviteCode: "HOPS").hasSuffix("HOPS"))
  }
}
