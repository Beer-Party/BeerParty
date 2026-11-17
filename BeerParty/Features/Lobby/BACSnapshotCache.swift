import Foundation

/// Remembers the last BAC snapshot together with the inputs it was built from.
/// The lobby screen asks for a snapshot on every render; typing in the drink form
/// re-renders it on each keystroke, and without the cache every keystroke would
/// re-run the BAC simulation for every member.
final class BACSnapshotCache {
  private struct Inputs: Equatable {
    let members: [LobbyMemberData]
    let drinks: [LobbyDrink]
    let paramsByUserId: [UUID: LobbyBACParamsData]
    let timestamp: Date
  }

  private var cached: (inputs: Inputs, snapshot: BacSnapshot)?

  /// How many times the simulation has actually run. Read by the unit tests.
  private(set) var simulationCount = 0

  func snapshot(
    members: [LobbyMemberData],
    drinks: [LobbyDrink],
    paramsByUserId: [UUID: LobbyBACParamsData],
    at timestamp: Date
  ) -> BacSnapshot {
    let inputs = Inputs(
      members: members,
      drinks: drinks,
      paramsByUserId: paramsByUserId,
      timestamp: timestamp
    )
    if let cached, cached.inputs == inputs {
      return cached.snapshot
    }

    let snapshot = BACCalculator.snapshot(
      members: members,
      drinks: drinks,
      paramsByUserId: paramsByUserId,
      at: timestamp
    )
    simulationCount += 1
    cached = (inputs, snapshot)
    return snapshot
  }
}
