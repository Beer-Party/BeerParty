import SwiftUI

struct RootView: View {
  @EnvironmentObject var authVM: AuthViewModel

  var body: some View {
    Group {
      if authVM.isSignedIn {
        switch authVM.profileState {
        case .unknown:
          ProgressView("Checking profile...")
        case .needsProfile:
          ProfileSetupView()
        case .complete:
          PreLobbyView()
        case .checkFailed:
          ContentUnavailableView {
            Label("Couldn't load your profile", systemImage: "wifi.exclamationmark")
          } description: {
            Text("Check your connection and try again.")
          } actions: {
            Button("Try again") {
              Task { await authVM.refreshProfileState() }
            }
            .buttonStyle(.borderedProminent)
          }
        }
      } else {
        LoginView()
      }
    }
  }
}
