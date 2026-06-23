import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 16.2, *)
struct LobbyQuickAddActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let presets: [QuickAddDrinkPreset]
    let lastCustomPreset: QuickAddDrinkPreset?
    let activeMotionID: String?
    let activeMotionTargetText: String?
    let shouldShowMotionVote: Bool?
    let updatedAt: Date
  }

  let lobbyID: String
  let lobbyName: String
}

struct BeerPartyWidgetLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LobbyQuickAddActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 8) {
        Text(context.attributes.lobbyName)
          .font(.headline)
          .lineLimit(1)

        if (context.state.shouldShowMotionVote ?? false), let target = context.state.activeMotionTargetText {
          VStack(alignment: .leading, spacing: 6) {
            Text("Motion: \(target)")
              .font(.subheadline.weight(.semibold))
              .lineLimit(2)
            HStack(spacing: 8) {
              motionVoteButton("Aye 🏴‍☠️", .aye)
              motionVoteButton("Neigh 🐴", .neigh)
            }
          }
        }

        quickButtonRow(customPreset: context.state.lastCustomPreset)
      }
      .padding(12)
      .activityBackgroundTint(.black.opacity(0.18))
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 8) {
            if (context.state.shouldShowMotionVote ?? false), let target = context.state.activeMotionTargetText {
              VStack(spacing: 6) {
                Text("Motion: \(target)")
                  .font(.caption.weight(.semibold))
                  .lineLimit(1)
                HStack(spacing: 8) {
                  motionVoteButton("Aye 🏴‍☠️", .aye)
                  motionVoteButton("Neigh 🐴", .neigh)
                }
              }
            }
            quickButtonRow(customPreset: context.state.lastCustomPreset)
          }
        }

        DynamicIslandExpandedRegion(.bottom) {
          EmptyView()
        }
      } compactLeading: {
        quickButton("🍺", .beer)
      } compactTrailing: {
        quickButton("💧", .water)
      } minimal: {
        Image(systemName: "drop.fill")
      }
    }
  }

  @ViewBuilder
  private func quickButtonRow(customPreset: QuickAddDrinkPreset?) -> some View {
    HStack(spacing: 8) {
      quickButton("🍺", .beer)
      quickButton("🍷", .wine)
      quickButton("🥃", .shot)
      quickButton("💧", .water)
      if customPreset != nil {
        quickButton("Custom", .custom)
      }
    }
  }

  @ViewBuilder
  private func motionVoteButton(_ title: String, _ choice: MotionVoteIntentChoice) -> some View {
    if #available(iOS 17.0, *) {
      Button(intent: CastMotionVoteIntent(vote: choice)) {
        Text(title)
          .font(.caption.weight(.semibold))
          .lineLimit(1)
          .padding(.horizontal, 10)
          .frame(height: 34)
          .background(.ultraThinMaterial, in: Capsule())
      }
      .buttonStyle(.plain)
    } else {
      Text(title)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
    }
  }

  @ViewBuilder
  private func quickButton(_ title: String, _ choice: QuickAddChoice) -> some View {
    if #available(iOS 17.0, *) {
      Button(intent: QuickAddDrinkIntent(preset: choice)) {
        Text(title)
          .font(title.count > 2 ? .caption.weight(.semibold) : .title3.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .frame(minWidth: 52, minHeight: 52)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(Color.white.opacity(0.10))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
          )
      }
      .buttonStyle(.plain)
    } else {
      Text(title)
        .font(title.count > 2 ? .caption.weight(.semibold) : .title3.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(minWidth: 52, minHeight: 52)
        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
  }
}
