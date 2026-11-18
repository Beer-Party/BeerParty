import Foundation

/// The name each member's line carries on the intoxication graph. Nothing stops
/// two members from choosing the same nickname; they then get "Anna" and
/// "Anna (2)", so each line keeps its own colour and label. No UI, no network.
enum BACSeriesLabels {
  /// One label per member, keyed by user id. A nickname used once is kept as it
  /// is. Nicknames that are the same apart from capitals and surrounding spaces
  /// count as the same; the extra members are numbered in user-id order, so every
  /// phone in the lobby shows the same numbers.
  static func labels(for members: [LobbyMemberData]) -> [UUID: String] {
    var labels: [UUID: String] = [:]
    var taken = Set(members.map(\.nickname))
    let groups = Dictionary(grouping: members) { member in
      member.nickname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    for key in groups.keys.sorted() {
      let ordered = (groups[key] ?? []).sorted { $0.userId.uuidString < $1.userId.uuidString }
      for (index, member) in ordered.enumerated() {
        guard index > 0 else {
          labels[member.userId] = member.nickname
          continue
        }
        let name = member.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        var number = index + 1
        var candidate = "\(name) (\(number))"
        while taken.contains(candidate) {
          number += 1
          candidate = "\(name) (\(number))"
        }
        taken.insert(candidate)
        labels[member.userId] = candidate
      }
    }
    return labels
  }
}
