//
//  LoginView.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import SwiftUI
import Supabase
import AuthenticationServices

struct LoginView: View {
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @State private var message: String = ""
  @State private var isLoading: Bool = false
  @State private var pulse = false
  @State private var isAtLeast18 = false
  @State private var acceptsNoDrinkDrive = false
  @State private var acceptsNoOverintoxicationDanger = false
  @State private var acceptsCareForLobbyMembers = false

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient(
          colors: [
            Color.orange.opacity(0.85),
            Color.yellow.opacity(0.72),
            Color.white
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        Circle()
          .fill(Color.white.opacity(0.25))
          .frame(width: 260, height: 260)
          .blur(radius: 10)
          .offset(x: -120, y: -220)
          .scaleEffect(pulse ? 1.08 : 0.94)
          .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

        VStack(spacing: 20) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to Beer Party")
              .font(.system(size: 38, weight: .heavy, design: .rounded))
              .frame(maxWidth: .infinity, alignment: .leading)

            Text("Track the vibe, watch the BAC curves, and keep the crew in sync.")
              .font(.body)
              .foregroundStyle(.black.opacity(0.72))
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          VStack(spacing: 14) {
            Label("Live BAC timeline", systemImage: "waveform.path.ecg")
            Label("Real-time lobby map", systemImage: "map.fill")
            Label("Quick drink shortcuts", systemImage: "bolt.fill")
          }
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

          VStack(alignment: .leading, spacing: 10) {
            Toggle("I confirm I am at least 18 years old.", isOn: $isAtLeast18)

            Text("This app does not provide medically accurate information regarding an individuals inebreation.")
              .font(.footnote)
              .foregroundStyle(.secondary)

            Text("Accept the following requirements before using the App:")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.secondary)

            Toggle("1. I will not drink and drive.", isOn: $acceptsNoDrinkDrive)
              .disabled(!isAtLeast18)
            Toggle("2. I will not become a danger to myself or others by way of overintoxication.", isOn: $acceptsNoOverintoxicationDanger)
              .disabled(!isAtLeast18)
            Toggle("3. I will look after other members within my lobby and ensure their safety.", isOn: $acceptsCareForLobbyMembers)
              .disabled(!isAtLeast18)
          }
          .font(.subheadline)
          .padding(14)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

          Button(isLoading ? "Signing in..." : "Continue with Google") {
            Task { await signInWithGoogle() }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 4)
          .buttonStyle(LiquidGlassButtonStyle())
          .foregroundStyle(.primary)
          .font(.headline)
          .disabled(isLoading || !canProceedToLogin)

          if !message.isEmpty {
            Text(message)
              .font(.footnote)
              .foregroundStyle(.black.opacity(0.72))
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(20)
      }
      .navigationTitle("Login")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        pulse = true
      }
    }
  }

  @MainActor
  private func signInWithGoogle() async {
    isLoading = true
    message = ""
    defer { isLoading = false }

    do {
      try await supabase.auth.signInWithOAuth(
        provider: .google,
        redirectTo: URL(string: "beerparty://login-callback")!,
        launchFlow: { @MainActor url in
          try await webAuthenticationSession.authenticate(
            using: url,
            callbackURLScheme: "beerparty"
          )
        }
      )
    } catch {
      message = "Google sign-in failed: \(readableAuthError(error))"
    }
  }

  private var canProceedToLogin: Bool {
    isAtLeast18
      && acceptsNoDrinkDrive
      && acceptsNoOverintoxicationDanger
      && acceptsCareForLobbyMembers
  }

  private func readableAuthError(_ error: Error) -> String {
    let nsError = error as NSError
    if nsError.domain == ASWebAuthenticationSessionError.errorDomain && nsError.code == 1 {
      return "Authentication was canceled. If this happened automatically, check callback URL config in Supabase and Google."
    }
    return error.localizedDescription
  }
}
