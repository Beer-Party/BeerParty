//
//  LobbyListView.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//

import SwiftUI
import Supabase

struct PreLobbyView: View {
  @EnvironmentObject var authVM: AuthViewModel
  @State private var status: String = ""
  @State private var isLoadingLobbies: Bool = false
  @State private var lobbyLoadError: String = ""
  @State private var isShowingCreateLobby: Bool = false
  @State private var isShowingJoinLobby: Bool = false
  @State private var isShowingProfileEditor: Bool = false
  @State private var selectedLobby: LobbyDestination?
  @State private var memberLobbies: [LobbyListItem] = []
  @State private var profilePicURL: URL?
  @State private var currentUserID: UUID?

  private let imageService = ProfileImageService()

  var body: some View {
    NavigationStack {
      ZStack {
        AeroBackground()

        ScrollView {
          VStack(spacing: 14) {
            HStack(spacing: 12) {
              profileAvatar
                .frame(width: 44, height: 44)

              VStack(alignment: .leading, spacing: 2) {
                Text("Lobby Hub")
                  .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Pick up where the party left off.")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }

              Spacer()
            }
            .padding(14)
            .aeroCard()

            HStack(spacing: 10) {
              Button {
                isShowingJoinLobby = true
              } label: {
                Label("Join Lobby", systemImage: "person.2.fill")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(AeroGlossButtonStyle())

              Button {
                isShowingCreateLobby = true
              } label: {
                Label("Make Lobby", systemImage: "sparkles")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(LiquidGlassButtonStyle())
            }

            VStack(alignment: .leading, spacing: 10) {
              Text("Your Lobbies")
                .font(.system(.headline, design: .rounded))

              if isLoadingLobbies && memberLobbies.isEmpty {
                HStack {
                  ProgressView()
                  Text("Loading lobbies...")
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
              } else if memberLobbies.isEmpty {
                // Not while the list could not be loaded: the error line below
                // says so, and "no lobbies yet" would be a guess.
                if lobbyLoadError.isEmpty {
                  LobbyListEmptyState()
                }
              } else {
                ForEach(memberLobbies) { lobby in
                  Button {
                    selectedLobby = lobby.destination
                  } label: {
                    lobbyRow(lobby)
                  }
                  .buttonStyle(.plain)
                }
              }

              if !lobbyLoadError.isEmpty {
                Text(lobbyLoadError)
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }

              if !status.isEmpty {
                Text(status)
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(14)
            .aeroCard()
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
        }
        .refreshable {
          // Own task: the reload changes view state, and SwiftUI can cancel the
          // refresh task (and the request with it) when the view updates.
          await Task { await loadInitialData() }.value
        }
      }
      .navigationTitle("Beer Party")
      .safeAreaInset(edge: .top) {
        if currentUserID != nil {
          HStack {
            Button {
              isShowingProfileEditor = true
            } label: {
              profileAvatar
                .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Sign Out") {
              Task { await signOut() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
          }
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .padding(.bottom, 6)
          .background(.clear)
        }
      }
      .onAppear {
        Task { await loadInitialData() }
      }
      .sheet(isPresented: $isShowingCreateLobby) {
        MakeLobbyView { destination in
          status = "Lobby \(destination.lobbyName) created."
          selectedLobby = destination
          if let currentUserID {
            Task { await loadMemberLobbies(for: currentUserID) }
          }
        }
      }
      .sheet(isPresented: $isShowingJoinLobby) {
        LobbyLoginView { destination in
          status = "Joined lobby \(destination.lobbyName)."
          selectedLobby = destination
          if let currentUserID {
            Task { await loadMemberLobbies(for: currentUserID) }
          }
        }
      }
      .sheet(isPresented: $isShowingProfileEditor) {
        ProfileSetupView(isEditingExisting: true) {
          if let currentUserID {
            Task { await loadProfileSummary(for: currentUserID) }
          }
        }
      }
      .navigationDestination(item: $selectedLobby) { destination in
        LobbyView(
          lobbyID: destination.lobbyID,
          lobbyName: destination.lobbyName
        )
      }
    }
  }

  @ViewBuilder
  private func lobbyRow(_ lobby: LobbyListItem) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(lobby.destination.lobbyName)
          .font(.body.weight(.semibold))
          .foregroundStyle(lobby.isActive ? .primary : .secondary)

        if lobby.isActive {
          Label("\(lobby.memberCount) member\(lobby.memberCount == 1 ? "" : "s")", systemImage: "person.2.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("Past lobby")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      if lobby.isActive {
        Text("ACTIVE")
          .font(.caption2.bold())
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .foregroundStyle(AeroTheme.leaf)
          .background(AeroTheme.leaf.opacity(0.18), in: Capsule())
      } else {
        Text(formattedLobbyDate(lobby.createdAt))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(lobby.isActive ? AeroTheme.aqua.opacity(0.16) : Color.white.opacity(0.05))
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(lobby.isActive ? AeroTheme.aqua.opacity(0.75) : Color.white.opacity(0.12), lineWidth: lobby.isActive ? 1.2 : 1)
        )
        .shadow(color: lobby.isActive ? AeroTheme.aqua.opacity(0.35) : .clear, radius: lobby.isActive ? 8 : 0, x: 0, y: 0)
    )
  }

  private var profileAvatar: some View {
    Group {
      if let profilePicURL {
        AsyncImage(url: profilePicURL) { phase in
          switch phase {
          case .success(let image):
            image.resizable()
          default:
            Image(systemName: "person.crop.circle.fill")
              .resizable()
              .symbolRenderingMode(.hierarchical)
          }
        }
      } else {
        Image(systemName: "person.crop.circle.fill")
          .resizable()
          .symbolRenderingMode(.hierarchical)
      }
    }
    .scaledToFill()
    .frame(width: 32, height: 32)
    .clipShape(Circle())
  }

  @MainActor
  private func loadInitialData() async {
    do {
      let session = try await supabase.auth.session
      currentUserID = session.user.id
      await loadProfileSummary(for: session.user.id)
      await loadMemberLobbies(for: session.user.id)
    } catch {
      currentUserID = nil
      memberLobbies = []
      profilePicURL = nil
      status = "Could not load session. Please sign in again."
    }
  }

  @MainActor
  private func signOut() async {
    // The Lock Screen buttons act as this user with a saved access token. End them
    // first, so they are gone even when the sign-out request itself fails.
    LobbyLiveActivityService().endContext()
    do {
      try await supabase.auth.signOut()
      await authVM.loadInitialSession()
    } catch {
      status = UserFacingError.message(couldNot: "sign out", error: error)
    }
  }

  @MainActor
  private func loadMemberLobbies(for userID: UUID) async {
    isLoadingLobbies = true
    defer { isLoadingLobbies = false }

    do {
      let memberships: [LobbyMembershipRow] = try await supabase
        .from("lobby_members")
        .select("lobby_id")
        .eq("user_id", value: userID)
        .execute()
        .value

      if memberships.isEmpty {
        memberLobbies = []
        lobbyLoadError = ""
        return
      }

      let lobbyIDs = memberships.map(\.lobbyID)
      let lobbies: [LobbyListSummaryRow] = try await supabase
        .from("lobbies")
        .select("id,name,is_active,created_at")
        .in("id", values: lobbyIDs)
        .execute()
        .value

      let memberRows: [LobbyMemberCountRow] = try await supabase
        .from("lobby_members")
        .select("lobby_id")
        .in("lobby_id", values: lobbyIDs)
        .execute()
        .value
      let countsByLobbyID = Dictionary(grouping: memberRows, by: \.lobbyID).mapValues(\.count)

      let loaded = lobbies.map { lobby in
        LobbyListItem(
          destination: LobbyDestination(lobbyID: lobby.id, lobbyName: lobby.name),
          isActive: lobby.isActive,
          memberCount: countsByLobbyID[lobby.id] ?? 1,
          createdAt: parseLobbyTimestamp(lobby.createdAtRaw)
        )
      }
      memberLobbies = LobbyListItem.afterReload(shown: memberLobbies, loaded: loaded)
      lobbyLoadError = ""
    } catch {
      // Keep the rows already shown: one failed request should not empty the list.
      memberLobbies = LobbyListItem.afterReload(shown: memberLobbies, loaded: nil)
      lobbyLoadError = UserFacingError.message(couldNot: "load your lobbies", error: error)
    }
  }

  @MainActor
  private func loadProfileSummary(for userID: UUID) async {
    do {
      let profile: UserProfile = try await supabase
        .from("profiles")
        .select("id,weight,age,gender,profile_pic_path,share_location_foreground,share_location_background")
        .eq("id", value: userID)
        .single()
        .execute()
        .value
      profilePicURL = imageService.publicImageURL(for: profile.profilePicPath)
    } catch {
      profilePicURL = nil
    }
  }

  private func parseLobbyTimestamp(_ value: String?) -> Date? {
    guard let value else { return nil }
    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = isoWithFraction.date(from: value) {
      return parsed
    }

    let isoWithoutFraction = ISO8601DateFormatter()
    isoWithoutFraction.formatOptions = [.withInternetDateTime]
    return isoWithoutFraction.date(from: value)
  }

  private func formattedLobbyDate(_ date: Date?) -> String {
    guard let date else { return "Unknown" }
    return date.formatted(.dateTime.day().month(.abbreviated))
  }
}

private struct LobbyListSummaryRow: Decodable {
  let id: UUID
  let name: String
  let isActive: Bool
  let createdAtRaw: String?

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case isActive = "is_active"
    case createdAtRaw = "created_at"
  }
}

private struct LobbyMemberCountRow: Decodable {
  let lobbyID: UUID

  enum CodingKeys: String, CodingKey {
    case lobbyID = "lobby_id"
  }
}
