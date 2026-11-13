//
//  LobbyView.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import SwiftUI
import Charts
import Combine
import MapKit
import CoreLocation

struct LobbyView: View {
  private enum BACTimeframe: String, CaseIterable, Identifiable {
    case past2Hours = "2h"
    case past5Hours = "5h"
    case all = "All"

    var id: Self { self }

    var label: String { rawValue }

    var duration: TimeInterval? {
      switch self {
      case .past2Hours:
        return 2 * 60 * 60
      case .past5Hours:
        return 5 * 60 * 60
      case .all:
        return nil
      }
    }
  }

  private enum DrinkInputField: Hashable {
    case drinkName
    case volume
    case abv
  }

  let lobbyID: UUID
  let lobbyName: String
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase

  @State private var drinkName: String = ""
  @State private var volumeMl: String = ""
  @State private var abv: String = ""
  @State private var statusMessage: String = ""
  @State private var isSubmitting: Bool = false
  @State private var isLoadingAnalytics: Bool = false
  @State private var now: Date = Date()
  @State private var members: [LobbyMemberData] = []
  @State private var drinks: [LobbyDrink] = []
  @State private var bacParamsByUserId: [UUID: LobbyBACParamsData] = [:]
  @State private var currentUserID: UUID?
  @State private var isLobbyActive: Bool = true
  @State private var lobbyCreatorID: UUID?
  @State private var lastBacSyncedAt: Date?
  @State private var lastBacSyncedValue: Double?
  @State private var lastDrinkCursor: Date?
  @State private var revealedInviteCode: String?
  @State private var isRevealingInviteCode: Bool = false
  @State private var hideInviteCodeTask: Task<Void, Never>?
  @State private var isLifecycleActionLoading: Bool = false
  @State private var isDeleteArmed: Bool = false
  @State private var isCloseArmed: Bool = false
  @State private var clearDeleteArmTask: Task<Void, Never>?
  @State private var clearCloseArmTask: Task<Void, Never>?
  @State private var mapRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
  )
  @State private var mapPosition: MapCameraPosition = .region(
    MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
      span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
    )
  )
  @State private var locationRows: [MemberLocationData] = []
  @State private var currentUserShareForeground = false
  @State private var currentUserShareBackground = false
  @State private var hasCenteredMap = false
  @State private var lockScreenAccessToken: String?
  @State private var lastCustomPreset: QuickAddDrinkPreset?
  @State private var isQuickAddWidgetEnabled = false
  @State private var shouldUseManualDrinkAsWidgetCustom = true
  @State private var selectedTimeframe: BACTimeframe = .all
  @State private var customVisibleDuration: TimeInterval?
  @State private var pinchStartDuration: TimeInterval?
  @State private var inspectedPoint: BACPoint?
  @State private var isInspectionActive = false
  @State private var isSendingMadeItHome = false
  @State private var motionTargetText: String = ""
  @State private var motionDelayMinutes: Int = 15
  @State private var motions: [LobbyMotion] = []
  @State private var isCreatingMotion = false
  @State private var isRefreshingMotions = false
  @State private var motionVoteInFlightID: UUID?
  @State private var isPastMotionsExpanded = false
  @State private var selectedBuddyID: UUID?
  @State private var lobbyClosedAt: Date?
  @State private var isDrinkHistoryExpanded = false
  @State private var editingDrink: LobbyDrink?
  @State private var editDrinkName: String = ""
  @State private var editVolumeMl: String = ""
  @State private var editAbv: String = ""
  @State private var isSavingDrinkEdit = false
  @State private var drinkMutationInFlightID: UUID?
  @FocusState private var focusedDrinkInput: DrinkInputField?

  private let liveTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
  private let bacSyncTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
  private let locationRefreshTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
  private let backendCoordinator = LobbyViewBackendCoordinator()
  @StateObject private var locationTrackingService = LocationTrackingService()
  private let imageService = ProfileImageService()
  private let liveActivityService = LobbyLiveActivityService()
  private let quickAddColumns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
  ]
  private let standardBeerGrams = 330.0 * 0.05 * 0.789
  private let motionDelayOptions = Array(stride(from: 5, through: 45, by: 5))

  // Renders the lobby UI, including live BAC, chart, and drink entry controls.
  var body: some View {
    let snapshot = buildBacSnapshot(at: now)
    let chartData = graphDisplayData(from: snapshot)
    let buddyCandidates = buddyCandidates(from: snapshot)
    let buddyComparison = buddyComparison(from: snapshot)

    ZStack(alignment: .top) {
      Form {
        Section {
          Color.clear
            .frame(height: 156)
            .listRowBackground(Color.clear)
        }

        Section {
          Text(lobbyName)
            .font(.largeTitle.bold())

          Text("Lobby ID: \(lobbyID.uuidString)")
            .font(.footnote)
            .foregroundStyle(.secondary)

          Text(isLobbyActive ? "Status: Active" : "Status: Closed")
            .font(.footnote)
            .foregroundStyle(isLobbyActive ? .green : .red)

          Button(isRevealingInviteCode ? "Revealing..." : "Reveal invite code") {
            Task { await revealInviteCodeTemporarily() }
          }
          .font(.footnote)
          .disabled(isRevealingInviteCode)

          if let revealedInviteCode {
            Text("Invite code: \(revealedInviteCode)")
              .font(.footnote.monospaced())
          }
        }

        if let activeMotion {
          Section("Active Motion") {
            VStack(alignment: .leading, spacing: 10) {
              Text("Motion towards \(activeMotion.targetText) in \(activeMotion.delayMinutes) min")
                .font(.headline)
              Text("Proposed by \(activeMotion.proposerNickname)")
                .font(.footnote)
                .foregroundStyle(.secondary)
              Text("Voting closes \(activeMotion.votingClosesAt, style: .relative) or when all members vote.")
                .font(.footnote)
                .foregroundStyle(.secondary)
              Text("Aye: \(activeMotion.ayeCount) • Neigh: \(activeMotion.neighCount)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)

              if let currentUserID, activeMotion.votes.contains(where: { $0.userId == currentUserID }) {
                Text("You already voted.")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.green)
              } else {
                HStack(spacing: 12) {
                  Button(motionVoteInFlightID == activeMotion.id ? "Voting..." : "Aye 🏴‍☠️") {
                    Task { await castMotionVote(motionID: activeMotion.id, vote: .aye) }
                  }
                  .buttonStyle(.borderedProminent)
                  .tint(.green)
                  .disabled(motionVoteInFlightID != nil)

                  Button(motionVoteInFlightID == activeMotion.id ? "Voting..." : "Neigh 🐴") {
                    Task { await castMotionVote(motionID: activeMotion.id, vote: .neigh) }
                  }
                  .buttonStyle(.bordered)
                  .tint(.orange)
                  .disabled(motionVoteInFlightID != nil)
                }
              }
            }
            .padding(.vertical, 4)
          }
        }

        Section("Live BAC") {
          if isLoadingAnalytics {
            ProgressView("Loading lobby drinks...")
          } else if snapshot.current.isEmpty {
            Text("No members found in this lobby.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(snapshot.current) { member in
              HStack {
                Text(member.nickname)
                Spacer()
                Text("\(member.bac, specifier: "%.2f")‰")
                  .monospacedDigit()
              }
            }
          }
        }

        Section("Buddy") {
          if snapshot.current.count <= 1 {
            Text("Buddy comparison appears once another member joins.")
              .foregroundStyle(.secondary)
          } else {
            Picker("Buddy", selection: $selectedBuddyID) {
              Text("None").tag(UUID?.none)
              ForEach(buddyCandidates) { buddy in
                Text(buddy.nickname).tag(Optional(buddy.userId))
              }
            }

            if let buddyComparison {
              VStack(alignment: .leading, spacing: 6) {
                if buddyComparison.isEven {
                  Text("You and \(buddyComparison.buddyNickname) are neck-and-neck.")
                    .font(.subheadline.bold())
                } else {
                  Text(
                    "You are \(buddyComparison.isAhead ? "ahead of" : "behind") \(buddyComparison.buddyNickname)."
                  )
                  .font(.subheadline.bold())
                }

                Text("BAC difference: \(buddyComparison.bacGap, specifier: "%.2f")‰")
                  .font(.footnote)
                  .foregroundStyle(.secondary)
                Text(
                  "About \(buddyComparison.standardBeerGap, specifier: "%.2f") standard beers \(buddyComparison.isAhead ? "ahead" : "behind")."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
              }
              .padding(.vertical, 6)
            }
          }
        }

        Section("Lobby Intoxication Graph") {
          if snapshot.points.isEmpty {
            Text("No drinks recorded yet.")
              .foregroundStyle(.secondary)
          } else {
            Picker("Timeframe", selection: $selectedTimeframe) {
              ForEach(BACTimeframe.allCases) { timeframe in
                Text(timeframe.label).tag(timeframe)
              }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTimeframe) { _, _ in
              customVisibleDuration = nil
              inspectedPoint = nil
              isInspectionActive = false
            }

            Chart(chartData.points) { point in
              LineMark(
                x: .value("Time", point.time),
                y: .value("BAC", point.bac),
                series: .value("Member", point.nickname)
              )
              .interpolationMethod(.catmullRom)
              .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
              .foregroundStyle(by: .value("Member", point.nickname))

              if let rightLabelPoint = chartData.latestPointByMember[point.nickname], rightLabelPoint.id == point.id {
                PointMark(
                  x: .value("Time", point.time),
                  y: .value("BAC", point.bac)
                )
                .foregroundStyle(by: .value("Member", point.nickname))
                .symbolSize(18)
                .annotation(position: .trailing, alignment: .leading) {
                  Text(point.nickname)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
              }

              if let inspectedPoint, inspectedPoint.id == point.id {
                PointMark(
                  x: .value("Time", point.time),
                  y: .value("BAC", point.bac)
                )
                .foregroundStyle(.primary)
                .symbol(.circle)
                .symbolSize(80)
              }
            }
            .chartXAxis {
              AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute(), centered: true)
              }
            }
            .chartYAxis {
              AxisMarks(position: .leading)
            }
            .chartYScale(domain: 0...chartData.maxY)
            .chartXScale(domain: chartData.xDomain)
            .chartPlotStyle { plotArea in
              plotArea
                .padding(.trailing, 90)
            }
            .chartOverlay { proxy in
              GeometryReader { geometry in
                Rectangle()
                  .fill(.clear)
                  .contentShape(Rectangle())
                  .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.25)
                      .sequenced(before: DragGesture(minimumDistance: 0))
                      .onChanged { value in
                        switch value {
                        case .first(true):
                          isInspectionActive = true
                        case .second(true, let drag):
                          guard let drag else { return }
                          isInspectionActive = true
                          updateInspectedPoint(
                            location: drag.location,
                            chartProxy: proxy,
                            geometry: geometry,
                            points: chartData.points,
                            maxY: chartData.maxY
                          )
                        default:
                          break
                        }
                      }
                      .onEnded { _ in
                        isInspectionActive = false
                        inspectedPoint = nil
                      }
                  )
                  .simultaneousGesture(
                    MagnificationGesture()
                      .onChanged { scale in
                        guard let baseDuration = chartData.baseDuration else { return }
                        if pinchStartDuration == nil {
                          pinchStartDuration = chartData.visibleDuration
                        }

                        guard let startDuration = pinchStartDuration else { return }
                        let clamped = max(20 * 60, min(baseDuration, startDuration / Double(scale)))
                        customVisibleDuration = clamped
                        inspectedPoint = nil
                        isInspectionActive = false
                      }
                      .onEnded { _ in
                        pinchStartDuration = nil
                      }
                  )
              }
            }
            .frame(height: 320)
            .padding(.vertical, 8)

            if isInspectionActive, let inspectedPoint {
              HStack {
                Text(inspectedPoint.nickname)
                  .font(.caption.bold())
                Spacer()
                Text("\(inspectedPoint.time, style: .time)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text("\(inspectedPoint.bac, specifier: "%.3f")‰")
                  .font(.caption.monospacedDigit())
              }
              .padding(.top, 4)
            }
          }
        }

        Section("Member Map") {
          if scenePhase != .active {
            Text("Map pauses while app is in background.")
              .foregroundStyle(.secondary)
          } else if visibleLocationRows.isEmpty {
            Text("No live member locations yet.")
              .foregroundStyle(.secondary)
          } else {
            Map(position: $mapPosition) {
              ForEach(visibleLocationRows) { row in
                Annotation(
                  row.nickname,
                  coordinate: CLLocationCoordinate2D(latitude: row.lat, longitude: row.lng)
                ) {
                  VStack(spacing: 4) {
                    mapAvatar(for: row.profilePicPath)
                    Text(row.nickname)
                      .font(.caption2)
                      .lineLimit(1)
                  }
                }
              }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 10))
          }

          Toggle("Share my location in foreground", isOn: $currentUserShareForeground)
            .onChange(of: currentUserShareForeground) { _, _ in
              Task { await updateLocationSharingPreference() }
            }

          Toggle("Share my location in background", isOn: $currentUserShareBackground)
            .disabled(!currentUserShareForeground)
            .onChange(of: currentUserShareBackground) { _, _ in
              Task { await updateLocationSharingPreference() }
            }
        }

        if isLobbyActive {
          Section("Add Drink") {
            TextField("Drink name", text: $drinkName)
              .textInputAutocapitalization(.words)
              .autocorrectionDisabled()
              .focused($focusedDrinkInput, equals: .drinkName)

            TextField("Volume (ml)", text: $volumeMl)
              .keyboardType(.decimalPad)
              .focused($focusedDrinkInput, equals: .volume)

            TextField("ABV (%)", text: $abv)
              .keyboardType(.decimalPad)
              .focused($focusedDrinkInput, equals: .abv)

            Toggle("Use as widget custom button", isOn: $shouldUseManualDrinkAsWidgetCustom)

            Button(isSubmitting ? "Adding..." : "Add Drink") {
              Task { await addManualDrink() }
            }
            .disabled(isSubmitting || !canAddManualDrink || !isLobbyActive)
          }

          Section("Widget") {
            Toggle("Lock Screen Quick Add", isOn: $isQuickAddWidgetEnabled)
              .disabled(!isLobbyActive)
              .onChange(of: isQuickAddWidgetEnabled) { _, enabled in
                Task { await setQuickAddWidgetEnabled(enabled) }
              }

            if let lastCustomPreset {
              Text("Custom button: \(lastCustomPreset.name) • \(lastCustomPreset.volumeMl, specifier: "%.0f") ml • \(lastCustomPreset.abv, specifier: "%.1f")%")
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
              Text("Add a manual drink with “Use as widget custom button” enabled to show a fifth widget button.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }
        }

        Section("Lobby Actions") {
          VStack(spacing: 16) {
            actionGlassButton(
              title: isSendingMadeItHome ? "Sending..." : "Made it home",
              glow: .blue,
              disabled: isSendingMadeItHome || !isLobbyActive || currentUserNickname == nil
            ) {
              Task { await sendMadeItHome() }
            }

            if currentUserIsCreator {
              if isLobbyActive {
                actionGlassButton(
                  title: isCloseArmed ? "Confirm Closing Time" : "Closing Time",
                  glow: .purple,
                  disabled: isLifecycleActionLoading || !isLobbyActive
                ) {
                  Task { await closeLobbyWithTwoStepConfirmation() }
                }
              }

              actionGlassButton(
                title: isDeleteArmed ? "Confirm Delete Lobby" : "Delete Lobby",
                glow: .red,
                disabled: isLifecycleActionLoading
              ) {
                Task { await deleteLobbyWithTwoStepConfirmation() }
              }
            } else {
              actionGlassButton(
                title: "Leave Lobby",
                glow: .orange,
                disabled: isLifecycleActionLoading
              ) {
                Task { await leaveLobby() }
              }
            }
          }
          .listRowBackground(Color.clear)
        }

        Section("Motions") {
          if !isLobbyActive {
            Text("Lobby is closed. New motions are disabled.")
              .foregroundStyle(.secondary)
          } else {
            TextField("Motion towards...", text: $motionTargetText)
              .textInputAutocapitalization(.sentences)
              .autocorrectionDisabled()

            Picker("In", selection: $motionDelayMinutes) {
              ForEach(motionDelayOptions, id: \.self) { minutes in
                Text("\(minutes) min").tag(minutes)
              }
            }

            Button(isCreatingMotion ? "Creating..." : "Create Motion") {
              Task { await createMotion() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(isCreatingMotion || motionTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || activeMotion != nil)

            if activeMotion != nil {
              Text("One active motion at a time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }

          let closedMotions = motions.filter { !$0.isActive }
          if closedMotions.isEmpty {
            Text("No past motions yet.")
              .foregroundStyle(.secondary)
          } else {
            DisclosureGroup(isExpanded: $isPastMotionsExpanded) {
              ForEach(closedMotions) { motion in
                VStack(alignment: .leading, spacing: 4) {
                  Text("Towards \(motion.targetText) in \(motion.delayMinutes) min")
                    .font(.subheadline.weight(.semibold))
                  Text("Aye \(motion.ayeCount) • Neigh \(motion.neighCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  if let passed = motion.passed {
                    Text(passed ? "Passed" : "Did not pass")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(passed ? .green : .red)
                  }
                  Text(motion.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
              }
            } label: {
              Text("Past Motions (\(closedMotions.count))")
                .font(.headline)
            }
          }
        }

        Section("Drink History") {
          if currentUserDrinkHistory.isEmpty {
            Text("No drinks logged yet.")
              .foregroundStyle(.secondary)
          } else {
            DisclosureGroup(
              isExpanded: $isDrinkHistoryExpanded,
              content: {
                ForEach(currentUserDrinkHistory) { drink in
                  VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                      VStack(alignment: .leading, spacing: 2) {
                        Text(drink.name)
                          .font(.subheadline.weight(.semibold))
                        Text("\(drink.volumeMl, specifier: "%.0f") ml • \(drink.abv, specifier: "%.1f")%")
                          .font(.caption)
                          .foregroundStyle(.secondary)
                      }
                      Spacer()
                      Text(drink.consumedAt, format: .dateTime.hour().minute())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }

                    if canModifyDrink(drink) {
                      HStack(spacing: 12) {
                        Button("Edit") {
                          beginEditingDrink(drink)
                        }
                        .buttonStyle(.borderless)
                        .disabled(drinkMutationInFlightID == drink.id)

                        Button("Delete", role: .destructive) {
                          Task { await deleteDrink(drink) }
                        }
                        .buttonStyle(.borderless)
                        .disabled(drinkMutationInFlightID == drink.id)
                      }
                      .font(.caption.weight(.semibold))
                    }
                  }
                  .padding(.vertical, 4)
                }
              },
              label: {
                Text("My Drinks Tonight (\(currentUserDrinkHistory.count))")
                  .font(.headline)
              }
            )
          }
        }

        if !statusMessage.isEmpty {
          Section {
            Text(statusMessage)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
      }

      if isLobbyActive {
        LazyVGrid(columns: quickAddColumns, spacing: 8) {
          quickAddEmojiButton("🍺") {
            Task { await addDrink(name: "Beer", volumeMl: 330, abv: 5) }
          }
          .disabled(isSubmitting || !isLobbyActive)

          quickAddEmojiButton("🍷") {
            Task { await addDrink(name: "Wine", volumeMl: 150, abv: 12) }
          }
          .disabled(isSubmitting || !isLobbyActive)

          quickAddEmojiButton("🥃") {
            Task { await addDrink(name: "Shot", volumeMl: 44, abv: 40) }
          }
          .disabled(isSubmitting || !isLobbyActive)

          quickAddEmojiButton("💧") {
            Task { await addDrink(name: "Water", volumeMl: 250, abv: 0) }
          }
          .disabled(isSubmitting || !isLobbyActive)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .background(Color.clear)
        .zIndex(3)
      }
    }
    .navigationTitle("Lobby")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await loadLobbyAnalytics()
    }
    .refreshable {
      await loadLobbyAnalytics()
    }
    .sheet(item: $editingDrink) { drink in
      NavigationStack {
        Form {
          Section("Drink Details") {
            TextField("Drink name", text: $editDrinkName)
              .textInputAutocapitalization(.words)
              .autocorrectionDisabled()

            TextField("Volume (ml)", text: $editVolumeMl)
              .keyboardType(.decimalPad)

            TextField("ABV (%)", text: $editAbv)
              .keyboardType(.decimalPad)
          }

          Section {
            Text("Drinks can be edited or deleted for 15 minutes after they are added.")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
        .navigationTitle("Edit Drink")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              editingDrink = nil
            }
            .disabled(isSavingDrinkEdit)
          }

          ToolbarItem(placement: .confirmationAction) {
            Button(isSavingDrinkEdit ? "Saving..." : "Save") {
              Task { await saveDrinkEdit(drink) }
            }
            .disabled(isSavingDrinkEdit || !canSaveDrinkEdit || !canModifyDrink(drink))
          }
        }
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .simultaneousGesture(
      TapGesture().onEnded {
        focusedDrinkInput = nil
      }
    )
    .onReceive(liveTimer) { latest in
      now = latest
      Task {
        await refreshLobbyActivityStatus()
        await refreshMembersIfNeeded()
        await refreshMotionsIfNeeded()
        if shouldContinueLiveUpdates {
          await refreshNewDrinksIfNeeded()
        } else {
          locationTrackingService.stopTracking()
        }
      }
    }
    .onReceive(bacSyncTimer) { latest in
      guard shouldContinueLiveUpdates else { return }
      Task { await syncCurrentUserBACIfNeeded(at: latest) }
    }
    .onReceive(locationRefreshTimer) { _ in
      guard shouldContinueLiveUpdates else {
        locationTrackingService.stopTracking()
        return
      }
      Task { await refreshMemberLocations() }
    }
    .onChange(of: members.map(\.userId)) { _, ids in
      if let selectedBuddyID, !ids.contains(selectedBuddyID) {
        self.selectedBuddyID = nil
      }
    }
    .onDisappear {
      hideInviteCodeTask?.cancel()
      hideInviteCodeTask = nil
      clearDeleteArmTask?.cancel()
      clearDeleteArmTask = nil
      clearCloseArmTask?.cancel()
      clearCloseArmTask = nil
      locationTrackingService.stopTracking()
    }
  }

  private var trimmedDrinkName: String {
    drinkName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canAddManualDrink: Bool {
    !trimmedDrinkName.isEmpty && parsedVolumeMl != nil && parsedAbv != nil
  }

  private var trimmedEditDrinkName: String {
    editDrinkName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canSaveDrinkEdit: Bool {
    !trimmedEditDrinkName.isEmpty && parsedEditVolumeMl != nil && parsedEditAbv != nil
  }

  private var parsedVolumeMl: Double? {
    guard let parsed = Double(volumeMl), parsed > 0 else { return nil }
    return parsed
  }

  private var parsedAbv: Double? {
    guard let parsed = Double(abv), parsed >= 0 else { return nil }
    return parsed
  }

  private var parsedEditVolumeMl: Double? {
    guard let parsed = Double(editVolumeMl), parsed > 0 else { return nil }
    return parsed
  }

  private var parsedEditAbv: Double? {
    guard let parsed = Double(editAbv), parsed >= 0 else { return nil }
    return parsed
  }

  private var visibleLocationRows: [MemberLocationData] {
    let staleCutoff = Date().addingTimeInterval(-5 * 60)
    return locationRows.filter { $0.updatedAt >= staleCutoff }
  }

  private var currentUserNickname: String? {
    guard let currentUserID else { return nil }
    return members.first(where: { $0.userId == currentUserID })?.nickname
  }

  private var currentUserDrinkHistory: [LobbyDrink] {
    guard let currentUserID else { return [] }
    return drinks
      .filter { $0.userId == currentUserID }
      .sorted { $0.consumedAt > $1.consumedAt }
  }

  private var currentUserIsCreator: Bool {
    guard let currentUserID else { return false }
    return lobbyCreatorID == currentUserID
  }

  private var activeMotion: LobbyMotion? {
    motions
      .filter { $0.isActive }
      .sorted { $0.createdAt > $1.createdAt }
      .first
  }

  private var shouldContinueLiveUpdates: Bool {
    if isLobbyActive {
      return true
    }
    guard let lobbyClosedAt else { return false }
    return Date().timeIntervalSince(lobbyClosedAt) < 5 * 60 * 60
  }

  private func canModifyDrink(_ drink: LobbyDrink) -> Bool {
    guard isLobbyActive, currentUserID == drink.userId, !isSystemEvent(drink) else { return false }
    let elapsed = now.timeIntervalSince(drink.consumedAt)
    return elapsed >= 0 && elapsed <= 15 * 60
  }

  private func quickAddEmojiButton(_ emoji: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(emoji)
        .font(.system(size: 34))
        .frame(maxWidth: .infinity)
        .frame(height: 60)
    }
    .buttonStyle(GlassButtonStyle())
  }

  private func actionGlassButton(
    title: String,
    glow: Color,
    disabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(.headline)
        .foregroundStyle(glow)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
    }
    .buttonStyle(LiquidGlassButtonStyle())
    .padding(.horizontal, 18)
    .shadow(color: glow.opacity(0.65), radius: 10, x: 0, y: 0)
    .disabled(disabled)
  }

  @ViewBuilder
  private func mapAvatar(for profilePicPath: String?) -> some View {
    if let url = imageService.publicImageURL(for: profilePicPath) {
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        default:
          Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFill()
            .symbolRenderingMode(.hierarchical)
        }
      }
      .frame(width: 38, height: 38)
      .clipShape(Circle())
      .overlay(Circle().stroke(Color.white, lineWidth: 2))
      .shadow(radius: 2)
    } else {
      Image(systemName: "person.crop.circle.fill")
        .resizable()
        .scaledToFill()
        .symbolRenderingMode(.hierarchical)
        .frame(width: 38, height: 38)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 2))
        .shadow(radius: 2)
    }
  }

  @MainActor
  // Validates manual inputs and forwards them to the shared add-drink flow.
  private func addManualDrink() async {
    guard let parsedVolumeMl, let parsedAbv else { return }
    let didInsert = await addDrink(name: trimmedDrinkName, volumeMl: parsedVolumeMl, abv: parsedAbv)
    if didInsert {
      let customPreset = QuickAddDrinkPreset(
        id: "custom",
        name: trimmedDrinkName,
        volumeMl: parsedVolumeMl,
        abv: parsedAbv
      )
      if shouldUseManualDrinkAsWidgetCustom {
        lastCustomPreset = customPreset
        liveActivityService.saveCustomPreset(customPreset, lobbyID: lobbyID)
        syncLiveActivityContext()
      }
    }
  }

  private func beginEditingDrink(_ drink: LobbyDrink) {
    editDrinkName = drink.name
    editVolumeMl = String(format: "%.0f", drink.volumeMl)
    editAbv = String(format: "%.1f", drink.abv)
    editingDrink = drink
  }

  @MainActor
  private func saveDrinkEdit(_ drink: LobbyDrink) async {
    guard canModifyDrink(drink) else {
      statusMessage = "Drinks can only be edited within 15 minutes of being added."
      editingDrink = nil
      return
    }
    guard let parsedEditVolumeMl, let parsedEditAbv else { return }

    isSavingDrinkEdit = true
    statusMessage = ""
    defer { isSavingDrinkEdit = false }

    do {
      let updatedDrink = try await backendCoordinator.updateDrink(
        lobbyID: lobbyID,
        drinkID: drink.id,
        name: trimmedEditDrinkName,
        volumeMl: parsedEditVolumeMl,
        abv: parsedEditAbv
      )

      if let index = drinks.firstIndex(where: { $0.id == updatedDrink.id }) {
        drinks[index] = updatedDrink
        drinks.sort { $0.consumedAt < $1.consumedAt }
      }

      editingDrink = nil
      statusMessage = "Updated \(updatedDrink.name)."
      await syncCurrentUserBACIfNeeded(at: Date(), force: true)
      syncLiveActivityContext()
    } catch {
      statusMessage = "Failed to update drink: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func deleteDrink(_ drink: LobbyDrink) async {
    guard canModifyDrink(drink) else {
      statusMessage = "Drinks can only be deleted within 15 minutes of being added."
      return
    }

    drinkMutationInFlightID = drink.id
    statusMessage = ""
    defer { drinkMutationInFlightID = nil }

    do {
      try await backendCoordinator.deleteDrink(lobbyID: lobbyID, drinkID: drink.id)
      drinks.removeAll { $0.id == drink.id }
      statusMessage = "Deleted \(drink.name)."
      await syncCurrentUserBACIfNeeded(at: Date(), force: true)
      syncLiveActivityContext()
    } catch {
      statusMessage = "Failed to delete drink: \(error.localizedDescription)"
    }
  }

  @MainActor
  // Inserts a drink via the backend service and refreshes local state/sync.
  private func addDrink(name: String, volumeMl volumeMlValue: Double, abv abvValue: Double) async -> Bool {
    guard isLobbyActive else {
      statusMessage = "This lobby is closed. Drinks can no longer be added."
      return false
    }

    isSubmitting = true
    statusMessage = ""
    defer { isSubmitting = false }

    do {
      let insertedDrink = try await backendCoordinator.insertDrink(
        lobbyID: lobbyID,
        name: name,
        volumeMl: volumeMlValue,
        abv: abvValue
      )
      currentUserID = insertedDrink.userId

      drinks.append(insertedDrink)
      drinks.sort { $0.consumedAt < $1.consumedAt }
      lastDrinkCursor = drinks.map(\.consumedAt).max()

      if name == trimmedDrinkName {
        drinkName = ""
        volumeMl = ""
        abv = ""
      }
      statusMessage = "Added \(name)."
      await syncCurrentUserBACIfNeeded(at: insertedDrink.consumedAt, force: true)
      syncLiveActivityContext()
      return true
    } catch {
      statusMessage = "Failed to add drink: \(error.localizedDescription)"
      return false
    }
  }

  @MainActor
  private func sendMadeItHome() async {
    guard let currentUserNickname else {
      statusMessage = "Could not determine your nickname."
      return
    }

    isSendingMadeItHome = true
    defer { isSendingMadeItHome = false }

    do {
      try await backendCoordinator.sendMadeItHome(lobbyID: lobbyID, nickname: currentUserNickname)
      statusMessage = "\(currentUserNickname) is safely at the fortress of dreams."
    } catch {
      statusMessage = "Failed to send made-it-home update: \(error.localizedDescription)"
    }
  }

  @MainActor
  // Loads lobby members, drinks, and BAC parameters used for local BAC calculations.
  private func loadLobbyAnalytics() async {
    isLoadingAnalytics = true
    defer { isLoadingAnalytics = false }

    do {
      let (meta, payload) = try await backendCoordinator.loadLobbyAnalytics(lobbyID: lobbyID)
      isLobbyActive = meta.isActive
      lobbyCreatorID = meta.createdBy
      currentUserID = payload.currentUserID
      if let authContext = try? await backendCoordinator.currentSessionAuthContext() {
        lockScreenAccessToken = authContext.accessToken
      }
      loadQuickAddWidgetState()
      members = payload.members
      lobbyClosedAt = payload.drinks.compactMap(closedAtTime).max()
      drinks = payload.drinks.filter { !isSystemEvent($0) }
      bacParamsByUserId = payload.bacParamsByUserId
      lastDrinkCursor = payload.drinks.map(\.consumedAt).max() ?? Date()
      now = Date()
      if !isLobbyActive {
        statusMessage = "Lobby closed. Drinking is disabled."
      }
      await syncCurrentUserBACIfNeeded(at: now, force: true)
      await loadLocationExperience()
      await refreshMotionsIfNeeded(force: true)
      syncLiveActivityContext()
    } catch {
      statusMessage = "Failed to load BAC tracker: \(error.localizedDescription)"
    }
  }

  // Picks up members who joined or left since the last full load. The member list
  // is reloaded only when the set of members has actually changed.
  @MainActor
  private func refreshMembersIfNeeded() async {
    guard shouldContinueLiveUpdates else { return }
    do {
      let latestMemberIDs = try await backendCoordinator.fetchLobbyMemberIDs(lobbyID: lobbyID)
      guard LobbyRoster.needsReload(
        shownMemberIDs: members.map(\.userId),
        latestMemberIDs: latestMemberIDs
      ) else { return }

      let roster = try await backendCoordinator.fetchLobbyRoster(lobbyID: lobbyID)
      members = roster.members
      bacParamsByUserId = roster.bacParamsByUserId
    } catch {
      // Ignore periodic refresh failures; manual refresh still reloads everything.
    }
  }

  // Pulls only new drinks since the last cursor to keep the graph fresh cheaply.
  private func refreshNewDrinksIfNeeded() async {
    guard shouldContinueLiveUpdates else {
      locationTrackingService.stopTracking()
      return
    }
    guard let cursor = lastDrinkCursor else { return }
    do {
      let newDrinks = try await backendCoordinator.fetchNewDrinks(lobbyID: lobbyID, after: cursor)
      guard !newDrinks.isEmpty else { return }

      if let closedAt = newDrinks.compactMap(closedAtTime).max() {
        lobbyClosedAt = closedAt
        isLobbyActive = false
        statusMessage = "Lobby closed. Live BAC and location updates end in 5 hours."
      } else if let motionTarget = newDrinks.compactMap(motionArrivalTarget).last {
        statusMessage = "Motion time: Head towards \(motionTarget)."
      } else if let latestHomeNickname = newDrinks.compactMap(madeItHomeNickname).last {
        statusMessage = "\(latestHomeNickname) is safely at the fortress of dreams."
      }

      let consumableDrinks = newDrinks.filter { !isSystemEvent($0) }
      if !consumableDrinks.isEmpty {
        drinks.append(contentsOf: consumableDrinks)
        drinks.sort { $0.consumedAt < $1.consumedAt }
      }
      lastDrinkCursor = newDrinks.map(\.consumedAt).max()
    } catch {
      // Ignore periodic refresh failures; manual refresh still reloads everything.
    }
  }

  @MainActor
  private func refreshLobbyActivityStatus() async {
    do {
      let meta = try await backendCoordinator.refreshLobbyMeta(lobbyID: lobbyID)
      lobbyCreatorID = meta.createdBy
      let wasActive = isLobbyActive
      isLobbyActive = meta.isActive
      if wasActive && !meta.isActive {
        if lobbyClosedAt == nil {
          lobbyClosedAt = Date()
        }
        isCloseArmed = false
        clearCloseArmTask?.cancel()
        clearCloseArmTask = nil
        liveActivityService.endContext()
        isQuickAddWidgetEnabled = false
        statusMessage = "Lobby closed. Drinking is disabled."
      }
    } catch {
      // Keep existing UI state on transient failures.
    }
  }

  private func isSystemEvent(_ drink: LobbyDrink) -> Bool {
    motionArrivalTarget(from: drink) != nil ||
      madeItHomeNickname(from: drink) != nil ||
      closedAtTime(from: drink) != nil
  }

  private func madeItHomeNickname(from drink: LobbyDrink) -> String? {
    guard drink.name.hasPrefix(LobbyBackendService.madeItHomeDrinkPrefix) else { return nil }
    let rawNickname = String(drink.name.dropFirst(LobbyBackendService.madeItHomeDrinkPrefix.count))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return rawNickname.isEmpty ? "Member" : rawNickname
  }

  private func closedAtTime(from drink: LobbyDrink) -> Date? {
    guard drink.name.hasPrefix(LobbyBackendService.lobbyClosedDrinkPrefix) else { return nil }
    let raw = String(drink.name.dropFirst(LobbyBackendService.lobbyClosedDrinkPrefix.count))
    let isoString = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
    guard !isoString.isEmpty else { return drink.consumedAt }
    let isoWithFractions = ISO8601DateFormatter()
    isoWithFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = isoWithFractions.date(from: isoString) {
      return parsed
    }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: isoString) ?? drink.consumedAt
  }

  private func motionArrivalTarget(from drink: LobbyDrink) -> String? {
    guard drink.name.hasPrefix(LobbyBackendService.motionArrivedDrinkPrefix) else { return nil }
    let raw = String(drink.name.dropFirst(LobbyBackendService.motionArrivedDrinkPrefix.count))
    let segments = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
    guard segments.count == 2 else { return nil }
    let target = String(segments[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    return target.isEmpty ? "the destination" : target
  }

  @MainActor
  private func createMotion() async {
    guard isLobbyActive else {
      statusMessage = "Lobby is closed. Cannot create motions."
      return
    }
    guard activeMotion == nil else {
      statusMessage = "There is already an active motion."
      return
    }
    guard let currentUserNickname else {
      statusMessage = "Could not determine your nickname."
      return
    }
    let target = motionTargetText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !target.isEmpty else { return }

    isCreatingMotion = true
    defer { isCreatingMotion = false }

    do {
      _ = try await backendCoordinator.createMotion(
        lobbyID: lobbyID,
        targetText: target,
        delayMinutes: motionDelayMinutes,
        proposerNickname: currentUserNickname
      )
      motionTargetText = ""
      statusMessage = "Motion opened for voting."
      await refreshMotionsIfNeeded(force: true)
    } catch {
      statusMessage = "Failed to create motion: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func castMotionVote(motionID: UUID, vote: MotionVoteChoice) async {
    motionVoteInFlightID = motionID
    defer { motionVoteInFlightID = nil }
    do {
      try await backendCoordinator.castMotionVote(
        lobbyID: lobbyID,
        motionID: motionID,
        vote: vote
      )
      statusMessage = vote == .aye ? "Aye vote submitted." : "Neigh vote submitted."
      await refreshMotionsIfNeeded(force: true)
    } catch {
      statusMessage = "Failed to submit vote: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func refreshMotionsIfNeeded(force: Bool = false) async {
    guard !isRefreshingMotions || force else { return }
    isRefreshingMotions = true
    defer { isRefreshingMotions = false }

    do {
      let fetched = try await backendCoordinator.fetchMotions(lobbyID: lobbyID)
      motions = fetched
      await resolveAndNotifyMotionsIfNeeded(from: fetched)
      syncLiveActivityContext()
    } catch {
      // Ignore transient failures.
    }
  }

  @MainActor
  private func resolveAndNotifyMotionsIfNeeded(from allMotions: [LobbyMotion]) async {
    let memberCount = max(1, members.count)
    let now = Date()

    for motion in allMotions where motion.isActive {
      let allVoted = motion.votes.count >= memberCount
      let voteWindowExpired = now >= motion.votingClosesAt
      guard allVoted || voteWindowExpired else { continue }

      let passed = (Double(motion.ayeCount) / Double(memberCount)) > (2.0 / 3.0)
      try? await backendCoordinator.closeMotion(motionID: motion.id, passed: passed)
    }

    let latest = (try? await backendCoordinator.fetchMotions(lobbyID: lobbyID)) ?? allMotions
    motions = latest

    for motion in latest where !motion.isActive {
      guard motion.passed == true, motion.targetAt <= now, motion.notifiedAt == nil else { continue }
      let didNotify = (try? await backendCoordinator.notifyMotionArrivalIfNeeded(
        lobbyID: lobbyID,
        motionID: motion.id,
        targetText: motion.targetText
      )) ?? false
      if didNotify {
        statusMessage = "Motion time: Head towards \(motion.targetText)."
      }
    }
  }

  private func buddyCandidates(from snapshot: BacSnapshot) -> [MemberBACSnapshot] {
    guard let currentUserID else { return [] }
    return snapshot.current.filter { $0.userId != currentUserID }
  }

  private func buddyComparison(from snapshot: BacSnapshot) -> BuddyComparisonData? {
    guard let currentUserID,
          let selectedBuddyID,
          let me = snapshot.current.first(where: { $0.userId == currentUserID }),
          let buddy = snapshot.current.first(where: { $0.userId == selectedBuddyID }) else {
      return nil
    }

    let bacGapSigned = me.bac - buddy.bac
    let bacGap = abs(bacGapSigned)
    let parameters = bacParameters(for: bacParamsByUserId[currentUserID])
    let alcoholGramsGap = bacGap * parameters.tbw / 0.84
    let standardBeerGap = alcoholGramsGap / standardBeerGrams

    return BuddyComparisonData(
      buddyNickname: buddy.nickname,
      bacGap: bacGap,
      standardBeerGap: standardBeerGap,
      isAhead: bacGapSigned >= 0
    )
  }

  private func graphDisplayData(from snapshot: BacSnapshot) -> BacGraphDisplayData {
    guard let earliestTime = snapshot.points.map(\.time).min(),
          let latestTime = snapshot.points.map(\.time).max() else {
      return BacGraphDisplayData(
        points: [],
        latestPointByMember: [:],
        xDomain: now...now,
        maxY: snapshot.maxY,
        baseDuration: nil,
        visibleDuration: nil
      )
    }

    let baseStart: Date
    if let duration = selectedTimeframe.duration {
      baseStart = max(earliestTime, latestTime.addingTimeInterval(-duration))
    } else {
      baseStart = earliestTime
    }

    let baseDomain = baseStart...latestTime
    let baseDuration = max(baseDomain.upperBound.timeIntervalSince(baseDomain.lowerBound), 60)
    let currentDuration = max(20 * 60, min(baseDuration, customVisibleDuration ?? baseDuration))
    let visibleStart = max(baseDomain.lowerBound, baseDomain.upperBound.addingTimeInterval(-currentDuration))
    let visibleDomain = visibleStart...baseDomain.upperBound

    let filteredPoints = snapshot.points.filter { visibleDomain.contains($0.time) }
    let latestPointByMember = Dictionary(
      grouping: filteredPoints,
      by: \.nickname
    ).compactMapValues { memberPoints in
      memberPoints.max { $0.time < $1.time }
    }

    let visibleMaxY = max(
      0.05,
      filteredPoints.map(\.bac).max() ?? snapshot.maxY
    )

    return BacGraphDisplayData(
      points: filteredPoints,
      latestPointByMember: latestPointByMember,
      xDomain: visibleDomain,
      maxY: visibleMaxY,
      baseDuration: baseDuration,
      visibleDuration: currentDuration
    )
  }

  private func updateInspectedPoint(
    location: CGPoint,
    chartProxy: ChartProxy,
    geometry: GeometryProxy,
    points: [BACPoint],
    maxY: Double
  ) {
    guard !points.isEmpty else {
      inspectedPoint = nil
      return
    }

    guard let plotFrame = chartProxy.plotFrame else {
      inspectedPoint = nil
      return
    }

    let plotRect = geometry[plotFrame]
    guard plotRect.contains(location) else {
      inspectedPoint = nil
      return
    }

    let xPosition = location.x - plotRect.origin.x
    let yPosition = location.y - plotRect.origin.y
    guard let hoveredTime: Date = chartProxy.value(atX: xPosition, as: Date.self) else {
      inspectedPoint = nil
      return
    }
    let hoveredBAC: Double? = chartProxy.value(atY: yPosition, as: Double.self)

    let nearest = points.min { lhs, rhs in
      pointDistanceScore(
        point: lhs,
        hoveredTime: hoveredTime,
        hoveredBAC: hoveredBAC,
        maxY: maxY
      ) < pointDistanceScore(
        point: rhs,
        hoveredTime: hoveredTime,
        hoveredBAC: hoveredBAC,
        maxY: maxY
      )
    }

    inspectedPoint = nearest
  }

  private func pointDistanceScore(
    point: BACPoint,
    hoveredTime: Date,
    hoveredBAC: Double?,
    maxY: Double
  ) -> Double {
    let timeDistanceSeconds = abs(point.time.timeIntervalSince(hoveredTime))
    let normalizedTimeDistance = timeDistanceSeconds / 120
    let normalizedBacDistance: Double
    if let hoveredBAC {
      normalizedBacDistance = abs(point.bac - hoveredBAC) / max(maxY, 0.05)
    } else {
      normalizedBacDistance = 0
    }
    return normalizedTimeDistance + normalizedBacDistance
  }

  @MainActor
  private func loadLocationExperience() async {
    guard let currentUserID else { return }

    let settings = await backendCoordinator.fetchLocationSharingSettings(userID: currentUserID)
    currentUserShareForeground = settings.shareForeground
    currentUserShareBackground = settings.shareBackground

    locationTrackingService.onLocationUpdate = { location in
      Task { await handleOwnLocationUpdate(location) }
    }

    refreshLocationTrackingState()
    await refreshMemberLocations()
  }

  @MainActor
  private func refreshLocationTrackingState() {
    guard shouldContinueLiveUpdates else {
      locationTrackingService.stopTracking()
      return
    }

    if currentUserShareForeground {
      locationTrackingService.startTracking(allowsBackground: currentUserShareBackground)
    } else {
      locationTrackingService.stopTracking()
      if let currentUserID {
        Task {
          try? await backendCoordinator.clearMemberLocation(lobbyID: lobbyID, userID: currentUserID)
          await refreshMemberLocations()
        }
      }
    }
  }

  @MainActor
  private func updateLocationSharingPreference() async {
    if !currentUserShareForeground {
      currentUserShareBackground = false
    }

    guard let userID = currentUserID else { return }
    do {
      try await backendCoordinator.saveLocationSharingPreference(
        userID: userID,
        shareForeground: currentUserShareForeground,
        shareBackground: currentUserShareForeground && currentUserShareBackground
      )
      refreshLocationTrackingState()
    } catch {
      statusMessage = "Failed to save location preference: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func handleOwnLocationUpdate(_ location: CLLocation) async {
    guard currentUserShareForeground else { return }
    guard let currentUserID else { return }

    do {
      try await backendCoordinator.upsertMemberLocation(
        lobbyID: lobbyID,
        userID: currentUserID,
        lat: location.coordinate.latitude,
        lng: location.coordinate.longitude,
        timestamp: Date()
      )
      await refreshMemberLocations()
    } catch {
      statusMessage = "Failed to sync location: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func refreshMemberLocations() async {
    do {
      let rows = try await backendCoordinator.fetchMemberLocations(lobbyID: lobbyID)
      locationRows = rows

      if !hasCenteredMap, let first = rows.first {
        mapRegion.center = CLLocationCoordinate2D(latitude: first.lat, longitude: first.lng)
        mapPosition = .region(mapRegion)
        hasCenteredMap = true
      }
    } catch {
      // Ignore transient map refresh failures.
    }
  }

  @MainActor
  private func loadQuickAddWidgetState() {
    if let savedCustomPreset = liveActivityService.savedCustomPreset(lobbyID: lobbyID) {
      lastCustomPreset = savedCustomPreset
    }

    guard let activeContext = liveActivityService.activeContext(),
          activeContext.lobbyID == lobbyID else {
      isQuickAddWidgetEnabled = false
      return
    }

    guard isLobbyActive else {
      isQuickAddWidgetEnabled = false
      liveActivityService.endContext()
      return
    }

    isQuickAddWidgetEnabled = true
    if lastCustomPreset == nil {
      lastCustomPreset = activeContext.lastCustomPreset
    }
  }

  @MainActor
  private func setQuickAddWidgetEnabled(_ enabled: Bool) async {
    guard enabled else {
      liveActivityService.endContext()
      statusMessage = "Widget quick add deactivated."
      return
    }

    guard isLobbyActive else {
      isQuickAddWidgetEnabled = false
      liveActivityService.endContext()
      statusMessage = "This lobby is closed. Widget quick add is unavailable."
      return
    }

    if lockScreenAccessToken == nil,
       let authContext = try? await backendCoordinator.currentSessionAuthContext()
    {
      currentUserID = authContext.userID
      lockScreenAccessToken = authContext.accessToken
    }

    guard currentUserID != nil, lockScreenAccessToken != nil else {
      isQuickAddWidgetEnabled = false
      statusMessage = "Could not activate widget quick add. Please sign in again."
      return
    }

    syncLiveActivityContext()
    statusMessage = "Widget quick add activated."
  }

  private func syncLiveActivityContext() {
    guard isQuickAddWidgetEnabled, isLobbyActive else { return }
    guard let userID = currentUserID, let token = lockScreenAccessToken else { return }
    let pendingMotion = activeMotion
    let shouldShowPendingVote: Bool
    if let pendingMotion {
      shouldShowPendingVote = !pendingMotion.votes.contains(where: { $0.userId == userID })
    } else {
      shouldShowPendingVote = false
    }

    liveActivityService.updateContext(
      lobbyID: lobbyID,
      lobbyName: lobbyName,
      userID: userID,
      accessToken: token,
      lastCustomPreset: lastCustomPreset,
      activeMotionID: pendingMotion?.id,
      activeMotionTargetText: pendingMotion?.targetText,
      shouldShowMotionVote: shouldShowPendingVote
    )
  }

  @MainActor
  // Fetches and shows the lobby invite code briefly, then hides it again.
  private func revealInviteCodeTemporarily() async {
    isRevealingInviteCode = true
    defer { isRevealingInviteCode = false }

    do {
      let inviteCode = try await backendCoordinator.revealInviteCode(lobbyID: lobbyID)
      revealedInviteCode = inviteCode
      hideInviteCodeTask?.cancel()
      hideInviteCodeTask = Task {
        try? await Task.sleep(nanoseconds: 10_000_000_000)
        if !Task.isCancelled {
          await MainActor.run {
            revealedInviteCode = nil
          }
        }
      }
    } catch {
      statusMessage = "Failed to reveal invite code: \(error.localizedDescription)"
    }
  }

  @MainActor
  // Allows only the creator to manually close the lobby.
  private func closeLobby() async {
    guard currentUserIsCreator else {
      statusMessage = "Only the lobby creator can close the lobby."
      return
    }

    isLifecycleActionLoading = true
    defer { isLifecycleActionLoading = false }

    do {
      try await backendCoordinator.closeLobby(lobbyID: lobbyID, closingBy: currentUserNickname)
      liveActivityService.endContext()
      isQuickAddWidgetEnabled = false
      isLobbyActive = false
      lobbyClosedAt = Date()
      statusMessage = "Closing time. Lobby is now closed. Live updates end in 5 hours."
    } catch {
      statusMessage = "Failed to close lobby: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func closeLobbyWithTwoStepConfirmation() async {
    if !isCloseArmed {
      isCloseArmed = true
      statusMessage = "Tap 'Confirm Closing Time' within 8 seconds to close the lobby."
      clearCloseArmTask?.cancel()
      clearCloseArmTask = Task {
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        if !Task.isCancelled {
          await MainActor.run {
            isCloseArmed = false
          }
        }
      }
      return
    }

    isCloseArmed = false
    clearCloseArmTask?.cancel()
    clearCloseArmTask = nil
    await closeLobby()
  }

  @MainActor
  // Removes the current member and their lobby-specific data, then exits the lobby view.
  private func leaveLobby() async {
    isLifecycleActionLoading = true
    defer { isLifecycleActionLoading = false }

    do {
      try await backendCoordinator.leaveLobby(lobbyID: lobbyID)
      liveActivityService.endContext()
      isQuickAddWidgetEnabled = false
      dismiss()
    } catch {
      statusMessage = "Failed to leave lobby: \(error.localizedDescription)"
    }
  }

  @MainActor
  // Requires two taps to delete a lobby and all associated lobby data.
  private func deleteLobbyWithTwoStepConfirmation() async {
    if !isDeleteArmed {
      isDeleteArmed = true
      statusMessage = "Tap 'Confirm Delete Lobby' within 8 seconds to delete permanently."
      clearDeleteArmTask?.cancel()
      clearDeleteArmTask = Task {
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        if !Task.isCancelled {
          await MainActor.run {
            isDeleteArmed = false
          }
        }
      }
      return
    }

    isLifecycleActionLoading = true
    defer { isLifecycleActionLoading = false }

    do {
      try await backendCoordinator.deleteLobby(lobbyID: lobbyID)
      liveActivityService.endContext()
      isQuickAddWidgetEnabled = false
      isDeleteArmed = false
      clearDeleteArmTask?.cancel()
      clearDeleteArmTask = nil
      dismiss()
    } catch {
      statusMessage = "Failed to delete lobby: \(error.localizedDescription)"
    }
  }

  @MainActor
  // Periodically upserts this user's computed BAC into member_state.
  private func syncCurrentUserBACIfNeeded(at timestamp: Date, force: Bool = false) async {
    guard shouldContinueLiveUpdates else { return }
    let minSyncIntervalSeconds: TimeInterval = 240
    if !force, let lastSyncedAt = lastBacSyncedAt, timestamp.timeIntervalSince(lastSyncedAt) < minSyncIntervalSeconds {
      return
    }

    guard let userId = currentUserID else { return }
    let snapshot = buildBacSnapshot(at: timestamp)
    guard let myBAC = snapshot.current.first(where: { $0.userId == userId })?.bac else { return }

    if !force, let lastValue = lastBacSyncedValue, abs(lastValue - myBAC) < 0.005 {
      return
    }

    do {
      try await backendCoordinator.upsertMemberBAC(
        lobbyID: lobbyID,
        userID: userId,
        bac: myBAC,
        timestamp: timestamp
      )

      lastBacSyncedAt = timestamp
      lastBacSyncedValue = myBAC
    } catch {
      statusMessage = "Failed to sync BAC: \(error.localizedDescription)"
    }
  }

  // Builds current BAC values and timeline points for every member.
  private func buildBacSnapshot(at timestamp: Date) -> BacSnapshot {
    let sortedMembers = members.sorted {
      $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
    }
    var current: [MemberBACSnapshot] = []
    var points: [BACPoint] = []
    let hasAnyDrinks = !drinks.isEmpty

    let allDrinkTimes = drinks.map(\.consumedAt)
    let startTime = allDrinkTimes.min() ?? timestamp

    for member in sortedMembers {
      let memberDrinks = drinks.filter { $0.userId == member.userId }.sorted { $0.consumedAt < $1.consumedAt }
      let params = bacParamsByUserId[member.userId]
      let simulation = simulateBACTimeline(
        params: params,
        drinks: memberDrinks,
        start: startTime,
        end: timestamp,
        stepMinutes: 10
      )

      current.append(
        MemberBACSnapshot(
          userId: member.userId,
          nickname: member.nickname,
          bac: simulation.currentBAC
        )
      )

      if hasAnyDrinks {
        points.append(contentsOf: simulation.points.map {
          BACPoint(
            id: "\(member.userId.uuidString)-\($0.time.timeIntervalSince1970)",
            nickname: member.nickname,
            time: $0.time,
            bac: $0.bac
          )
        })
      }
    }

    let maxY = max(0.05, points.map(\.bac).max() ?? 0.05)
    let sortedCurrent = current.sorted { lhs, rhs in
      if lhs.bac == rhs.bac {
        return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
      }
      return lhs.bac > rhs.bac
    }
    return BacSnapshot(current: sortedCurrent, points: points, maxY: maxY)
  }

  // Simulates BAC over time using absorption and elimination at fixed time steps.
  private func simulateBACTimeline(
    params: LobbyBACParamsData?,
    drinks: [LobbyDrink],
    start: Date,
    end: Date,
    stepMinutes: Int
  ) -> BACSimulationResult {
    guard end >= start else {
      return BACSimulationResult(points: [TimelineBACPoint(time: end, bac: 0)], currentBAC: 0)
    }

    let parameters = bacParameters(for: params)
    let eliminationPerHourGrams = (parameters.eliminationPerHourPromille * parameters.tbw) / 0.84
    let sortedDrinks = drinks.sorted { $0.consumedAt < $1.consumedAt }
    let stepSeconds = TimeInterval(stepMinutes * 60)

    var points: [TimelineBACPoint] = []
    var currentTime = start
    var alcoholInBodyGrams: Double = 0

    points.append(TimelineBACPoint(time: currentTime, bac: 0))

    while currentTime < end {
      let nextTime = min(end, currentTime.addingTimeInterval(stepSeconds))
      let dtHours = nextTime.timeIntervalSince(currentTime) / 3600
      if dtHours <= 0 {
        currentTime = nextTime
        continue
      }

      var absorbedGrams: Double = 0
      for drink in sortedDrinks {
        let previousHours = currentTime.timeIntervalSince(drink.consumedAt) / 3600
        let currentHours = nextTime.timeIntervalSince(drink.consumedAt) / 3600
        let previousFraction = absorbedFraction(hoursSinceDrink: previousHours, abv: drink.abv)
        let currentFraction = absorbedFraction(hoursSinceDrink: currentHours, abv: drink.abv)
        let deltaFraction = max(0, currentFraction - previousFraction)
        absorbedGrams += drink.alcoholGrams * deltaFraction
      }

      alcoholInBodyGrams = max(
        0,
        alcoholInBodyGrams + absorbedGrams - eliminationPerHourGrams * dtHours
      )

      let currentBAC = max(0, (alcoholInBodyGrams / parameters.tbw) * 0.84)
      points.append(TimelineBACPoint(time: nextTime, bac: currentBAC))

      currentTime = nextTime
    }

    return BACSimulationResult(points: points, currentBAC: points.last?.bac ?? 0)
  }

  // Uses precomputed per-member BAC parameters to avoid reading raw profiles.
  private func bacParameters(for params: LobbyBACParamsData?) -> BACParameters {
    guard let params else {
      return BACParameters(tbw: 40, eliminationPerHourPromille: 0.14)
    }
    return BACParameters(
      tbw: max(20, params.tbw),
      eliminationPerHourPromille: max(0.08, min(0.2, params.eliminationPerHourPromille))
    )
  }

  // Returns what fraction of a drink is absorbed based on elapsed time and ABV.
  private func absorbedFraction(hoursSinceDrink: Double, abv: Double) -> Double {
    guard hoursSinceDrink > 0 else { return 0 }
    let absorptionDurationHours = min(max(1.6 - (abv * 0.03), 0.25), 1.6)
    return min(1, hoursSinceDrink / absorptionDurationHours)
  }

}

private struct BACParameters {
  let tbw: Double
  let eliminationPerHourPromille: Double
}

private struct TimelineBACPoint {
  let time: Date
  let bac: Double
}

private struct BACSimulationResult {
  let points: [TimelineBACPoint]
  let currentBAC: Double
}

private struct MemberBACSnapshot: Identifiable {
  let userId: UUID
  let nickname: String
  let bac: Double

  var id: UUID { userId }
}

private struct BACPoint: Identifiable {
  let id: String
  let nickname: String
  let time: Date
  let bac: Double
}

private struct BacSnapshot {
  let current: [MemberBACSnapshot]
  let points: [BACPoint]
  let maxY: Double
}

private struct BacGraphDisplayData {
  let points: [BACPoint]
  let latestPointByMember: [String: BACPoint]
  let xDomain: ClosedRange<Date>
  let maxY: Double
  let baseDuration: TimeInterval?
  let visibleDuration: TimeInterval?
}

private struct BuddyComparisonData {
  let buddyNickname: String
  let bacGap: Double
  let standardBeerGap: Double
  let isAhead: Bool

  var isEven: Bool {
    bacGap < 0.01
  }
}
