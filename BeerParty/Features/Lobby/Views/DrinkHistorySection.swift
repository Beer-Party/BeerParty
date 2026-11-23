import SwiftUI

/// The "Drink History" section of the lobby screen: the user's own drinks with
/// "Edit" and "Delete" on the ones that can still be changed. It only shows the
/// list; the lobby screen owns the drinks and does the editing and deleting.
struct DrinkHistorySection: View {
  /// The user's own drinks, newest first.
  let drinks: [LobbyDrink]
  @Binding var isExpanded: Bool
  /// The drink that is being saved or deleted right now, if any.
  let busyDrinkID: UUID?
  let canModify: (LobbyDrink) -> Bool
  let onEdit: (LobbyDrink) -> Void
  let onDelete: (LobbyDrink) -> Void

  var body: some View {
    Section("Drink History") {
      if drinks.isEmpty {
        Text("No drinks logged yet.")
          .foregroundStyle(.secondary)
      } else {
        DisclosureGroup(
          isExpanded: $isExpanded,
          content: {
            ForEach(drinks) { drink in
              row(for: drink)
            }
          },
          label: {
            Text("My Drinks Tonight (\(drinks.count))")
              .font(.headline)
          }
        )
      }
    }
  }

  private func row(for drink: LobbyDrink) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 2) {
          Text(drink.name)
            .font(.subheadline.weight(.semibold))
          Text("\(drink.volumeMl, specifier: "%.0f") ml • \(drink.abv, specifier: "%.1f")%")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text(drink.consumedAt, format: .dateTime.hour().minute())
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }

      if canModify(drink) {
        HStack(spacing: 12) {
          Button("Edit") {
            onEdit(drink)
          }
          .buttonStyle(.borderless)
          .disabled(busyDrinkID == drink.id)

          Button("Delete", role: .destructive) {
            onDelete(drink)
          }
          .buttonStyle(.borderless)
          .disabled(busyDrinkID == drink.id)
        }
        .font(.caption.weight(.semibold))
      }
    }
    .padding(.vertical, 4)
  }
}
