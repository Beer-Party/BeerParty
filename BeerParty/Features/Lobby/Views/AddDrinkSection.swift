import SwiftUI

/// The three text fields of the "Add Drink" form. The lobby screen owns the
/// focus, so that a tap anywhere on the screen can put the keyboard away.
enum DrinkInputField: Hashable {
  case drinkName
  case volume
  case abv
}

/// The "Add Drink" section of the lobby screen: name, volume and ABV, the
/// "Use as widget custom button" switch and the "Add Drink" button. It only
/// shows the form; the lobby screen owns the typed text and adds the drink.
/// The lobby screen shows this section only while the lobby is open.
struct AddDrinkSection: View {
  @Binding var draft: DrinkDraft
  @Binding var usesDrinkAsWidgetCustomButton: Bool
  var focusedField: FocusState<DrinkInputField?>.Binding
  /// True while a drink is being sent to the server.
  let isSubmitting: Bool
  let onAdd: () -> Void

  var body: some View {
    Section("Add Drink") {
      TextField("Drink name", text: $draft.name)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .focused(focusedField, equals: .drinkName)

      TextField("Volume (ml)", text: $draft.volumeText)
        .keyboardType(.decimalPad)
        .focused(focusedField, equals: .volume)

      TextField("ABV (%)", text: $draft.abvText)
        .keyboardType(.decimalPad)
        .focused(focusedField, equals: .abv)

      if let limitMessage = draft.limitMessage {
        Text(limitMessage)
          .font(.footnote)
          .foregroundStyle(.red)
      }

      Toggle("Use as widget custom button", isOn: $usesDrinkAsWidgetCustomButton)

      Button(isSubmitting ? "Adding..." : "Add Drink") {
        onAdd()
      }
      .disabled(isSubmitting || !draft.canSubmit)
    }
  }
}
