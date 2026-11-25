import SwiftUI

/// The lobby screen's status line ("Added Beer.", "Couldn't add the drink. ...")
/// as a banner fixed to the bottom of the screen. It used to be the last row of
/// the form, far below the buttons that cause it, so it was usually off screen.
struct LobbyStatusBanner: View {
  let message: String
  let onDismiss: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text(message)
        .font(.footnote)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)

      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .padding(6)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Dismiss message")
    }
    .padding(.leading, 14)
    .padding(.trailing, 8)
    .padding(.vertical, 10)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.white.opacity(0.18), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
    .padding(.horizontal, 14)
    .padding(.bottom, 8)
    .accessibilityElement(children: .contain)
  }
}
