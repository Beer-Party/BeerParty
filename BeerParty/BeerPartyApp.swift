//
//  BeerPartyApp.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/9/26.
//

import SwiftUI
import Supabase

@main
struct BeerPartyApp: App {
  @StateObject private var authVM = AuthViewModel()

  var body: some Scene {
    WindowGroup {
      ZStack {
        // Seen behind the screens that have no background of their own (the
        // profile check, its retry screen).
        AeroBackground()

        RootView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .tint(AeroTheme.aqua)
      .preferredColorScheme(.dark)
      .buttonStyle(LiquidGlassButtonStyle())
      .environmentObject(authVM)
      .onOpenURL { url in
        Task {
          do {
            try await supabase.auth.session(from: url)
          } catch {
            print("Deep link auth error:", error)
          }
        }
      }
    }
  }
}
