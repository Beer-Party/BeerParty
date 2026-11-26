import SwiftUI

/// Shown under "Your Lobbies" on the hub when the user is in no lobby: what the
/// app is waiting for and which of the two buttons above to use.
struct LobbyListEmptyState: View {
  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: "party.popper.fill")
        .font(.system(size: 30))
        .foregroundStyle(.yellow)
        .frame(width: 64, height: 64)
        .background(Color.yellow.opacity(0.14), in: Circle())
        .accessibilityHidden(true)

      Text("No lobbies yet")
        .font(.headline)

      Text("Tap “Make Lobby” to start one and share its invite code, or “Join Lobby” to enter a friend's code.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
    .padding(.horizontal, 8)
    .accessibilityElement(children: .combine)
  }
}
