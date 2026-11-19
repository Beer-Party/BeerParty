import XCTest
@testable import BeerParty

@MainActor
final class LobbyCreationTests: XCTestCase {

  private enum StepError: Error, Equatable {
    case createFailed
    case finishFailed
  }

  func testSuccessRunsCreateThenFinishAndUndoesNothing() async throws {
    var steps: [String] = []

    let created = try await LobbyCreation.perform(
      create: { () async throws -> String in
        steps.append("create")
        return "lobby"
      },
      finish: { (lobby: String) async throws -> Void in
        steps.append("finish \(lobby)")
      },
      undo: { (lobby: String) async -> Void in
        steps.append("undo \(lobby)")
      }
    )

    XCTAssertEqual(created, "lobby")
    XCTAssertEqual(steps, ["create", "finish lobby"])
  }

  // The half-made lobby is removed and the user sees why the attempt failed.
  func testFailedFinishUndoesWhatWasCreatedAndThrowsTheFinishError() async {
    var steps: [String] = []

    do {
      _ = try await LobbyCreation.perform(
        create: { () async throws -> String in
          steps.append("create")
          return "lobby"
        },
        finish: { (lobby: String) async throws -> Void in
          steps.append("finish \(lobby)")
          throw StepError.finishFailed
        },
        undo: { (lobby: String) async -> Void in
          steps.append("undo \(lobby)")
        }
      )
      XCTFail("Expected the finish error to be thrown")
    } catch {
      XCTAssertEqual(error as? StepError, .finishFailed)
    }

    XCTAssertEqual(steps, ["create", "finish lobby", "undo lobby"])
  }

  func testFailedCreateRunsNeitherFinishNorUndo() async {
    var steps: [String] = []

    do {
      _ = try await LobbyCreation.perform(
        create: { () async throws -> String in
          steps.append("create")
          throw StepError.createFailed
        },
        finish: { (lobby: String) async throws -> Void in
          steps.append("finish \(lobby)")
        },
        undo: { (lobby: String) async -> Void in
          steps.append("undo \(lobby)")
        }
      )
      XCTFail("Expected the create error to be thrown")
    } catch {
      XCTAssertEqual(error as? StepError, .createFailed)
    }

    XCTAssertEqual(steps, ["create"])
  }

  func testInviteCodeInUseIsShownAsItsOwnSentence() {
    XCTAssertEqual(
      UserFacingError.message(couldNot: "create the lobby", error: LobbyCreationError.inviteCodeInUse),
      "That invite code is already in use. Pick a different one."
    )
  }
}
