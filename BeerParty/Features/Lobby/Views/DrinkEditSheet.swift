import SwiftUI

/// The "Edit Drink" sheet of the lobby screen. It only shows the form: the lobby
/// screen owns the draft and does the saving.
struct DrinkEditSheet: View {
  @Binding var draft: DrinkDraft
  let isSaving: Bool
  /// False once the drink can no longer be changed (15 minutes, or lobby closed).
  let canModify: Bool
  let onCancel: () -> Void
  let onSave: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        Section("Drink Details") {
          TextField("Drink name", text: $draft.name)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

          TextField("Volume (ml)", text: $draft.volumeText)
            .keyboardType(.decimalPad)

          TextField("ABV (%)", text: $draft.abvText)
            .keyboardType(.decimalPad)

          if let limitMessage = draft.limitMessage {
            Text(limitMessage)
              .font(.footnote)
              .foregroundStyle(.red)
          }
        }

        Section {
          Text("Drinks can be edited or deleted for 15 minutes after they are added.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Edit Drink")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
            .disabled(isSaving)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "Saving..." : "Save", action: onSave)
            .disabled(isSaving || !draft.canSubmit || !canModify)
        }
      }
    }
  }
}
