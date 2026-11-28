import SwiftUI

/// The "Motions" section of the lobby screen: the form for a new motion and the
/// list of past motions. It only shows them; the lobby screen creates the
/// motion, keeps the list up to date and decides the results.
struct MotionsSection: View {
  /// The choices of the "In" picker, in minutes.
  static let delayOptions = Array(stride(from: 5, through: 45, by: 5))

  let isLobbyActive: Bool
  @Binding var targetText: String
  @Binding var delayMinutes: Int
  let isCreating: Bool
  /// Only one motion can be open for voting at a time.
  let hasActiveMotion: Bool
  /// Motions whose voting is over, newest first.
  let pastMotions: [LobbyMotion]
  @Binding var isPastExpanded: Bool
  let onCreate: () -> Void

  /// Why the typed destination is too long, or nil when it fits.
  private var targetLimitMessage: String? {
    NameLimits.message(for: targetText, kind: .motionDestination)
  }

  var body: some View {
    Section("Motions") {
      if !isLobbyActive {
        Text("Lobby is closed. New motions are disabled.")
          .foregroundStyle(.secondary)
      } else {
        TextField("Motion towards...", text: $targetText)
          .textInputAutocapitalization(.sentences)
          .autocorrectionDisabled()

        if let targetLimitMessage {
          Text(targetLimitMessage)
            .font(.footnote)
            .foregroundStyle(.red)
        }

        Picker("In", selection: $delayMinutes) {
          ForEach(Self.delayOptions, id: \.self) { minutes in
            Text("\(minutes) min").tag(minutes)
          }
        }

        Button(isCreating ? "Creating..." : "Create Motion", action: onCreate)
          .buttonStyle(.borderedProminent)
          .tint(.indigo)
          .disabled(
            isCreating
              || targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || targetLimitMessage != nil
              || hasActiveMotion
          )

        if hasActiveMotion {
          Text("One active motion at a time.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      if pastMotions.isEmpty {
        Text("No past motions yet.")
          .foregroundStyle(.secondary)
      } else {
        DisclosureGroup(isExpanded: $isPastExpanded) {
          ForEach(pastMotions) { motion in
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
          Text("Past Motions (\(pastMotions.count))")
            .font(.headline)
        }
      }
    }
  }
}
