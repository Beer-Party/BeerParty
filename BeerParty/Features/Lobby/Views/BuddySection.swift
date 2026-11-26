import SwiftUI

/// The "Buddy" section of the lobby screen: the picker for another member and
/// how the current user's BAC compares with theirs. It only shows them; the
/// lobby screen works out the comparison (`BuddyComparison`).
struct BuddySection: View {
  /// False while the current user is the only member with a BAC value.
  let hasOtherMembers: Bool
  /// The members that can be chosen: everyone but the current user.
  let candidates: [MemberBACSnapshot]
  @Binding var selectedBuddyID: UUID?
  /// nil while no buddy is chosen.
  let comparison: BuddyComparisonData?

  var body: some View {
    Section("Buddy") {
      if !hasOtherMembers {
        Text("Buddy comparison appears once another member joins.")
          .foregroundStyle(.secondary)
      } else {
        Picker("Buddy", selection: $selectedBuddyID) {
          Text("None").tag(UUID?.none)
          ForEach(candidates) { buddy in
            Text(buddy.nickname).tag(Optional(buddy.userId))
          }
        }

        if let comparison {
          VStack(alignment: .leading, spacing: 6) {
            Text(comparison.headline)
              .font(.subheadline.bold())

            Text("BAC difference: \(comparison.bacGap, specifier: "%.2f")‰")
              .font(.footnote)
              .foregroundStyle(.secondary)
            Text(
              "About \(comparison.standardBeerGap, specifier: "%.2f") standard beers \(comparison.isAhead ? "ahead" : "behind")."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
          }
          .padding(.vertical, 6)
        }
      }
    }
  }
}
