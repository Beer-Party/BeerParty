import SwiftUI

/// The "Live BAC" section of the lobby screen: one line per member with their
/// photo, name, a bar comparing them with the others, and the BAC value.
struct LiveBACSection: View {
  let isLoading: Bool
  let rows: [LiveBACRow]

  private let imageService = ProfileImageService()

  var body: some View {
    Section("Live BAC") {
      if isLoading {
        ProgressView("Loading lobby drinks...")
      } else if rows.isEmpty {
        Text("No members found in this lobby.")
          .foregroundStyle(.secondary)
      } else {
        ForEach(rows) { row in
          line(for: row)
        }
      }
    }
  }

  private func line(for row: LiveBACRow) -> some View {
    HStack(spacing: 12) {
      avatar(for: row.profilePicPath)

      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          Text(row.nickname)
            .font(.body.weight(row.isCurrentUser ? .semibold : .regular))
            .lineLimit(1)

          if row.isCurrentUser {
            Text("You")
              .font(.caption2.weight(.bold))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .foregroundStyle(AeroTheme.aqua)
              .background(AeroTheme.aqua.opacity(0.20), in: Capsule())
          }

          Spacer(minLength: 8)

          Text("\(row.bac, specifier: "%.2f")‰")
            .font(.body.weight(.semibold))
            .monospacedDigit()
        }

        bar(fraction: row.barFraction, isCurrentUser: row.isCurrentUser)
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(row.isCurrentUser ? "\(row.nickname), you" : row.nickname)
    .accessibilityValue(String(format: "%.2f per mille", row.bac))
  }

  private func bar(fraction: Double, isCurrentUser: Bool) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.white.opacity(0.10))
        Capsule()
          .fill(
            LinearGradient(
              colors: isCurrentUser
                ? [AeroTheme.aqua, AeroTheme.leaf]
                : [AeroTheme.sky.opacity(0.55), AeroTheme.aqua.opacity(0.70)],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: geometry.size.width * fraction)
      }
    }
    .frame(height: 6)
  }

  @ViewBuilder
  private func avatar(for profilePicPath: String?) -> some View {
    if let url = imageService.publicImageURL(for: profilePicPath) {
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        default:
          placeholderAvatar
        }
      }
      .frame(width: 34, height: 34)
      .clipShape(Circle())
    } else {
      placeholderAvatar
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }
  }

  private var placeholderAvatar: some View {
    Image(systemName: "person.crop.circle.fill")
      .resizable()
      .scaledToFill()
      .symbolRenderingMode(.hierarchical)
      .foregroundStyle(.secondary)
  }
}
