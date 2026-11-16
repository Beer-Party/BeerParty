//
//  AuthVIewModel.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import Foundation
import Supabase
import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {

  @Published var isSignedIn: Bool = false
  @Published var userId: UUID?
  @Published var profileState: ProfileState = .unknown
  private var authListenerTask: Task<Void, Never>?
  /// The user whose profile row has been confirmed to exist in this session.
  private var verifiedProfileUserId: UUID?

  init() {
    Task {
      await loadInitialSession()
      listenForAuthChanges()
    }
  }

  /// B6 lives here 👇
  func loadInitialSession() async {
    do {
      let session = try await supabase.auth.session
      self.isSignedIn = true
      self.userId = session.user.id
      await refreshProfileState()
    } catch {
      self.isSignedIn = false
      self.userId = nil
      self.profileState = .unknown
    }
  }

  func listenForAuthChanges() {
    authListenerTask?.cancel()
    authListenerTask = Task { [weak self] in
      guard let self else { return }

      for await (_, session) in supabase.auth.authStateChanges {
        await self.applyAuthState(session: session)
      }
    }
  }

  private func applyAuthState(session: Session?) async {
    if let session = session {
      self.isSignedIn = true
      self.userId = session.user.id
      await self.refreshProfileState()
    } else {
      self.isSignedIn = false
      self.userId = nil
      self.profileState = .unknown
      self.verifiedProfileUserId = nil
    }
  }

  func refreshProfileState() async {
    guard let userId = userId else {
      profileState = .unknown
      verifiedProfileUserId = nil
      return
    }

    // Auth events fire for the whole session, including the hourly token refresh.
    // Once this user's profile is known to exist, keep showing the app while it is
    // re-checked: going back to .unknown makes RootView swap to a spinner, which
    // tears down the lobby the user is in.
    let wasVerified = verifiedProfileUserId == userId
    profileState = ProfileState.whileChecking(current: profileState, alreadyVerified: wasVerified)

    do {
      let _: UserProfileLite = try await supabase
        .from("profiles")
        .select("id")
        .eq("id", value: userId)
        .single()
        .execute()
        .value
      verifiedProfileUserId = userId
      profileState = .complete
    } catch {
      // A failed re-check (offline, timeout) must not send a user whose profile was
      // already confirmed back to profile setup.
      if !wasVerified {
        profileState = .needsProfile
      }
    }
  }
}

enum ProfileState: Equatable {
  case unknown
  case needsProfile
  case complete

  /// The state to show while the profile is being checked. A profile that was
  /// already confirmed for this user stays as it is; anything else shows the spinner.
  static func whileChecking(current: ProfileState, alreadyVerified: Bool) -> ProfileState {
    alreadyVerified && current == .complete ? .complete : .unknown
  }
}

private struct UserProfileLite: Decodable {
  let id: UUID
}
