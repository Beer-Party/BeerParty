import Foundation
import Supabase

extension LobbyBackendService {
  /// The lobby's rows in `lobby_events`, oldest first; with `cursor`, only
  /// those created after it. The table lets members of the lobby read them.
  /// Rows of a kind this version does not know are left out.
  func fetchLobbyEvents(lobbyID: UUID, after cursor: Date? = nil) async throws -> [LobbyEventRecord] {
    var query = supabase
      .from("lobby_events")
      .select(LobbyEventRow.columns)
      .eq("lobby_id", value: lobbyID)

    if let cursor {
      query = query.gt("created_at", value: LobbyEventFeed.timestampText(cursor))
    }

    let rows: [LobbyEventRow] = try await query
      .order("created_at", ascending: true)
      .execute()
      .value

    return rows.compactMap(\.record)
  }
}
