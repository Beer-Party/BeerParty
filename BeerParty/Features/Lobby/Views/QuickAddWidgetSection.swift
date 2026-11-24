import SwiftUI

/// The "Widget" section of the lobby screen: the "Lock Screen Quick Add" switch
/// and a line describing the custom button. It only shows them; the lobby
/// screen starts and ends the Live Activity when the switch changes.
/// The lobby screen shows this section only while the lobby is open.
struct QuickAddWidgetSection: View {
  @Binding var isEnabled: Bool
  /// The fifth Lock Screen button, made from a manually added drink, if any.
  let customPreset: QuickAddDrinkPreset?
  /// Called with the new value whenever the switch changes, also when the lobby
  /// screen itself switches it off.
  let onEnabledChange: (Bool) -> Void

  var body: some View {
    Section("Widget") {
      Toggle("Lock Screen Quick Add", isOn: $isEnabled)
        .onChange(of: isEnabled) { _, enabled in
          onEnabledChange(enabled)
        }

      if let customPreset {
        Text("Custom button: \(customPreset.name) • \(customPreset.volumeMl, specifier: "%.0f") ml • \(customPreset.abv, specifier: "%.1f")%")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        Text("Add a manual drink with “Use as widget custom button” enabled to show a fifth widget button.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }
}
