import XCTest
@testable import BeerParty

@MainActor
final class LobbyGoneTests: XCTestCase {

  func testLobbyNotFoundMeansGone() {
    XCTAssertTrue(LobbyLifecycleError.meansLobbyIsGone(LobbyLifecycleError.lobbyNotFound))
  }

  func testOtherLobbyErrorsDoNotMeanGone() {
    XCTAssertFalse(LobbyLifecycleError.meansLobbyIsGone(LobbyLifecycleError.lobbyClosed))
    XCTAssertFalse(LobbyLifecycleError.meansLobbyIsGone(LobbyLifecycleError.notCreator))
    XCTAssertFalse(LobbyLifecycleError.meansLobbyIsGone(LobbyLifecycleError.closeDenied))
  }

  // Being offline must never throw the user out of the lobby.
  func testNetworkAndOtherErrorsDoNotMeanGone() {
    XCTAssertFalse(LobbyLifecycleError.meansLobbyIsGone(URLError(.notConnectedToInternet)))
    XCTAssertFalse(LobbyLifecycleError.meansLobbyIsGone(URLError(.timedOut)))
    XCTAssertFalse(LobbyLifecycleError.meansLobbyIsGone(DrinkMutationError.editWindowExpired))
    XCTAssertFalse(LobbyLifecycleError.meansLobbyIsGone(CancellationError()))
  }
}
