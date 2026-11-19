import Foundation

enum LobbyCreationError: LocalizedError {
  case inviteCodeInUse

  var errorDescription: String? {
    switch self {
    case .inviteCodeInUse:
      return "That invite code is already in use. Pick a different one."
    }
  }
}

/// Making a lobby takes several requests: the lobby row first, then the creator's
/// membership and state rows. The database has no single function for it yet, so
/// a failure after the first request would leave a lobby with no members, which
/// nobody can see and whose invite code stays taken.
enum LobbyCreation {
  /// Runs `create`, then `finish`. When `finish` fails, `undo` is run for what
  /// `create` made and the error from `finish` is thrown. When `create` itself
  /// fails there is nothing to undo.
  static func perform<Created>(
    create: () async throws -> Created,
    finish: (Created) async throws -> Void,
    undo: (Created) async -> Void
  ) async throws -> Created {
    let created = try await create()
    do {
      try await finish(created)
    } catch {
      await undo(created)
      throw error
    }
    return created
  }
}
