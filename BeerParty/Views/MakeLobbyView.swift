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
  @State private var lobbyPassword: String = ""
  @State private var nickname: String = ""
  @State private var message: String = ""
  @State private var isLoading: Bool = false
  private let backendService = LobbyBackendService()

  var body: some View {
    NavigationStack {
      Form {
        Section("New Lobby") {
          TextField("Lobby name", text: $lobbyName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

          TextField("Nickname", text: $nickname)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

          SecureField("Lobby password", text: $lobbyPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
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
    lobbyPassword.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  @MainActor
  private func createLobby() async {
    isLoading = true
    message = ""
    defer { isLoading = false }

    do {
      let session = try await supabase.auth.session
      let existingCodeRows: [InviteCodeOnlyRow] = try await supabase
        .from("lobbies")
        .select("invite_code")
        .eq("invite_code", value: trimmedInviteCode)
        .limit(1)
        .execute()
        .value

      if !existingCodeRows.isEmpty {
        message = "That invite code is already in use. Pick a different one."
        return
      }

      let request = CreateLobbyRequest(
        createdBy: session.user.id,
        name: trimmedName,
        inviteCode: trimmedInviteCode,
        isActive: true
      )

      let createdLobby: CreatedLobby = try await supabase
        .from("lobbies")
        .insert(request, returning: .representation)
        .single()
        .execute()
        .value

      let memberRequest = CreateLobbyMemberRequest(
        lobbyId: createdLobby.id,
        userId: session.user.id,
        nickname: trimmedNickname,
        role: "admin"
      )

      try await supabase
        .from("lobby_members")
        .insert(memberRequest)
        .execute()

      let memberStateRequest = UpsertMemberStateRequest(
        lobbyId: createdLobby.id,
        userId: session.user.id,
        bacEtimate: nil,
        lat: nil,
        lng: nil,
        updatedAt: Date()
      )

      try await supabase
        .from("member_state")
        .upsert(memberStateRequest, onConflict: "lobby_id,user_id")
        .execute()

      try await backendService.ensureBACParamsForCurrentUser(lobbyID: createdLobby.id)

      onCreated(
        LobbyDestination(
          lobbyID: createdLobby.id,
          lobbyName: createdLobby.name
        )
      )
      dismiss()
    } catch {
      message = "Failed to create lobby: \(error.localizedDescription)"
    }
  }
}

private struct InviteCodeOnlyRow: Decodable {
  let inviteCode: String

  enum CodingKeys: String, CodingKey {
    case inviteCode = "invite_code"
  }
}
