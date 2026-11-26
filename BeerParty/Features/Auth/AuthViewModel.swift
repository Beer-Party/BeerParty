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
      // Signed out, also when the session ended by itself (a refresh that was
      // refused, a sign-out on another screen): the Lock Screen quick-add must not
      // keep working with the previous user's access token.
      LobbyLiveActivityService().endContext()
      // The next person to sign in on this phone should not be offered the
      // previous user's nickname.
      LastNickname.clear()
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

    let result: ProfileCheckResult
    do {
      // A plain list, not .single(): .single() throws when there is no row, which
      // cannot be told apart from a request that failed.
      let rows: [UserProfileLite] = try await supabase
        .from("profiles")
        .select("id")
        .eq("id", value: userId)
        .limit(1)
        .execute()
        .value
      result = rows.isEmpty ? .missing : .found
    } catch {
      result = .failed
    }

    // The user may have signed out or changed while the request was running.
    guard self.userId == userId else { return }

    switch result {
    case .found:
      verifiedProfileUserId = userId
    case .missing:
      verifiedProfileUserId = nil
    case .failed:
      break
    }
    // Asked again here, not taken from before the request: another check for the
    // same user may have confirmed the profile in the meantime.
    profileState = ProfileState.afterCheck(
      result,
      alreadyVerified: verifiedProfileUserId == userId
    )
  }
}

/// What the profile lookup returned.
enum ProfileCheckResult: Equatable {
  /// The user has a profile row.
  case found
  /// The request worked and there is no row: a new user.
  case missing
  /// The request itself failed (offline, timeout, server error).
  case failed
}

enum ProfileState: Equatable {
  case unknown
  case needsProfile
  case complete
  /// The profile could not be checked. Shown with a retry, not as profile setup.
  case checkFailed

  /// The state to show while the profile is being checked. A profile that was
  /// already confirmed for this user stays as it is; anything else shows the spinner.
  static func whileChecking(current: ProfileState, alreadyVerified: Bool) -> ProfileState {
    alreadyVerified && current == .complete ? .complete : .unknown
  }

  /// The state to show once the check has finished. Only a request that worked and
  /// found no row sends the user to profile setup. A failed request keeps a profile
  /// that was already confirmed, and otherwise offers a retry.
  static func afterCheck(_ result: ProfileCheckResult, alreadyVerified: Bool) -> ProfileState {
    switch result {
    case .found:
      return .complete
    case .missing:
      return .needsProfile
    case .failed:
      return alreadyVerified ? .complete : .checkFailed
    }
  }
}

private struct UserProfileLite: Decodable {
  let id: UUID
}
