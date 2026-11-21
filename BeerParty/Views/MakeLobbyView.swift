//
//  MakeLobbyView.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import SwiftUI
import Supabase

struct MakeLobbyView: View {
  let onCreated: (_ destination: LobbyDestination) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var lobbyName: String = ""
  @State private var inviteCode: String = ""
  @State private var nickname: String = ""
  @State private var message: String = ""
  @State private var isLoading: Bool = false
  private let backendService = LobbyBackendService()

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Lobby name", text: $lobbyName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

          TextField("Nickname", text: $nickname)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

          // Shown as typed: the code is given to friends and is visible in the lobby.
          TextField("Invite code", text: $inviteCode)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        } header: {
          Text("New Lobby")
        } footer: {
          Text("Friends join with the invite code. Use at least 4 characters.")
        }

        if !message.isEmpty {
          Section {
            Text(message)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        Section {
          HStack(spacing: 10) {
            Button("Cancel") {
              dismiss()
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .disabled(isLoading)

            Button(isLoading ? "Creating..." : "Create") {
              Task { await createLobby() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(isLoading || !canSubmit)
          }
          .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
        }
      }
      .navigationTitle("Make Lobby")
    }
  }

  private var canSubmit: Bool {
    !trimmedName.isEmpty && !trimmedNickname.isEmpty && trimmedInviteCode.count >= 4
  }

  private var trimmedName: String {
    lobbyName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var trimmedNickname: String {
    nickname.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var trimmedInviteCode: String {
    inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  @MainActor
  private func createLobby() async {
    isLoading = true
    message = ""
    defer { isLoading = false }

    do {
      let destination = try await backendService.createLobby(
        name: trimmedName,
        inviteCode: trimmedInviteCode,
        nickname: trimmedNickname
      )
      onCreated(destination)
      dismiss()
    } catch {
      message = UserFacingError.message(couldNot: "create the lobby", error: error)
    }
  }
}
