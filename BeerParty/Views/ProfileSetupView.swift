//
//  ProfileSetupView.swift
//  BeerParty
//
//  Created by Codex on 2/11/26.
//
import SwiftUI
import Supabase
import PhotosUI
import UIKit

struct ProfileSetupView: View {
  private enum WeightUnit: String, CaseIterable, Identifiable {
    case pounds = "lbs"
    case kilograms = "kg"

    var id: Self { self }

    var label: String {
      switch self {
      case .pounds:
        return "lbs"
      case .kilograms:
        return "kg"
      }
    }
  }

  @EnvironmentObject var authVM: AuthViewModel
  @Environment(\.dismiss) private var dismiss

  let isEditingExisting: Bool
  var onSaved: (() -> Void)?

  @State private var weightText: String = ""
  @State private var selectedWeightUnit: WeightUnit = .pounds
  @State private var ageText: String = ""
  @State private var gender: String = ""
  @State private var shareLocationForeground = false
  @State private var shareLocationBackground = false

  @State private var profilePicPath: String?
  @State private var profilePicURL: URL?
  @State private var selectedPhotoItem: PhotosPickerItem?
  @State private var selectedPhotoData: Data?

  @State private var message: String = ""
  @State private var isLoading: Bool = false

  private let genderOptions = [
    "Male",
    "Female",
    "Non-binary",
    "Prefer not to say"
  ]

  private let imageService = ProfileImageService()

  init(isEditingExisting: Bool = false, onSaved: (() -> Void)? = nil) {
    self.isEditingExisting = isEditingExisting
    self.onSaved = onSaved
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Profile Picture") {
          HStack {
            Spacer()
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
              profileAvatar
            }
            Spacer()
          }

          Text("Max image size: 300 KB. Photos are compressed automatically.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Section("Profile") {
          TextField("Weight (\(selectedWeightUnit.label))", text: $weightText)
            .keyboardType(.decimalPad)

          Picker("Weight unit", selection: $selectedWeightUnit) {
            ForEach(WeightUnit.allCases) { unit in
              Text(unit.label).tag(unit)
            }
          }
          .pickerStyle(.segmented)
          .onChange(of: selectedWeightUnit) { previousUnit, nextUnit in
            convertDisplayedWeight(from: previousUnit, to: nextUnit)
          }

          TextField("Age", text: $ageText)
            .keyboardType(.numberPad)

          Picker("Gender", selection: $gender) {
            ForEach(genderOptions, id: \.self) { option in
              Text(option)
            }
          }
        }

        Section("Location Sharing") {
          Toggle("Share location in foreground", isOn: $shareLocationForeground)
            .onChange(of: shareLocationForeground) { _, isEnabled in
              if !isEnabled {
                shareLocationBackground = false
              }
            }

          Toggle("Share location in background", isOn: $shareLocationBackground)
            .disabled(!shareLocationForeground)

          Text("Background sharing works only when foreground sharing is enabled.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        if !message.isEmpty {
          Section {
            Text(message)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        Section {
          Button(isLoading ? "Saving..." : "Save Profile") {
            Task { await saveProfile() }
          }
          .disabled(isLoading || !canSubmit)
        }
      }
      .navigationTitle(isEditingExisting ? "Edit Profile" : "Your Profile")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        await loadExistingProfileIfAvailable()
      }
      .onChange(of: selectedPhotoItem) { _, newItem in
        guard let newItem else { return }
        Task { await loadSelectedPhoto(item: newItem) }
      }
    }
  }

  private var profileAvatar: some View {
    Group {
      if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
        Image(uiImage: image)
          .resizable()
      } else if let profilePicURL {
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
    .frame(width: 88, height: 88)
    .clipShape(Circle())
    .overlay(Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 1))
  }

  private var canSubmit: Bool {
    guard backendWeightPounds != nil else { return false }
    guard let age = Int(ageText), age > 0 else { return false }
    return !gender.isEmpty
  }

  private var backendWeightPounds: Double? {
    guard let enteredWeight = Double(weightText), enteredWeight > 0 else { return nil }
    switch selectedWeightUnit {
    case .pounds:
      return enteredWeight
    case .kilograms:
      return enteredWeight * 2.20462
    }
  }

  private func convertDisplayedWeight(from previousUnit: WeightUnit, to nextUnit: WeightUnit) {
    guard previousUnit != nextUnit,
          let displayedWeight = Double(weightText),
          displayedWeight > 0 else {
      return
    }

    let weightInPounds: Double
    switch previousUnit {
    case .pounds:
      weightInPounds = displayedWeight
    case .kilograms:
      weightInPounds = displayedWeight * 2.20462
    }

    let convertedWeight: Double
    switch nextUnit {
    case .pounds:
      convertedWeight = weightInPounds
    case .kilograms:
      convertedWeight = weightInPounds / 2.20462
    }

    weightText = formattedWeight(convertedWeight, unit: nextUnit)
  }

  private func formattedWeight(_ weight: Double, unit: WeightUnit) -> String {
    switch unit {
    case .pounds:
      return String(format: "%.0f", weight)
    case .kilograms:
      return String(format: "%.1f", weight)
    }
  }

  @MainActor
  private func loadExistingProfileIfAvailable() async {
    guard gender.isEmpty else { return }
    gender = genderOptions.first ?? ""

    guard let userId = authVM.userId else { return }

    do {
      let profile: UserProfile = try await supabase
        .from("profiles")
        .select("id,weight,age,gender,profile_pic_path,share_location_foreground,share_location_background")
        .eq("id", value: userId)
        .single()
        .execute()
        .value

      weightText = formattedWeight(profile.weight, unit: selectedWeightUnit)
      ageText = String(profile.age)
      gender = profile.gender
      shareLocationForeground = profile.shareLocationForeground
      shareLocationBackground = profile.shareLocationBackground
      profilePicPath = profile.profilePicPath
      profilePicURL = imageService.publicImageURL(for: profile.profilePicPath)
    } catch {
      if isEditingExisting {
        message = "Could not load profile. You can still create one now."
      }
    }
  }

  @MainActor
  private func loadSelectedPhoto(item: PhotosPickerItem) async {
    do {
      guard let data = try await item.loadTransferable(type: Data.self) else {
        message = "Could not read the selected photo."
        return
      }
      selectedPhotoData = data
      message = ""
    } catch {
      message = "Failed to load photo: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func saveProfile() async {
    isLoading = true
    message = ""
    defer { isLoading = false }

    guard let userId = authVM.userId else {
      message = "No active session. Please sign in again."
      return
    }

    guard let weight = backendWeightPounds, let age = Int(ageText) else {
      message = "Please enter a valid weight and age."
      return
    }

    var nextProfilePicPath = profilePicPath

    if let selectedPhotoData {
      do {
        let normalized = try imageService.normalizeForUpload(selectedPhotoData)
        nextProfilePicPath = try await imageService.uploadProfileImage(normalized, userId: userId)
      } catch {
        message = "Failed to upload profile photo: \(error.localizedDescription)"
        return
      }
    }

    let profile = UserProfile(
      id: userId,
      weight: weight,
      age: age,
      gender: gender,
      profilePicPath: nextProfilePicPath,
      shareLocationForeground: shareLocationForeground,
      shareLocationBackground: shareLocationForeground && shareLocationBackground
    )

    do {
      try await supabase
        .from("profiles")
        .upsert(profile)
        .execute()

      await authVM.refreshProfileState()
      onSaved?()

      if isEditingExisting {
        dismiss()
      }
    } catch {
      message = "Failed to save profile: \(error.localizedDescription)"
    }
  }
}
