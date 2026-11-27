import SwiftUI

/// The app's look: deep water with light in it. Dark, calm surfaces with a lot
/// of room, as in health apps such as Oura, and the glass, gloss, aqua and
/// fresh green of the "Frutiger Aero" years. Colours and shapes that more than
/// one screen uses live here, so the screens stay in step.
enum AeroTheme {
  /// The darkest tone, at the top and bottom of every screen.
  static let abyss = Color(red: 0.02, green: 0.06, blue: 0.14)
  /// The middle of the background.
  static let ocean = Color(red: 0.03, green: 0.20, blue: 0.34)
  /// The accent: buttons, switches, the active lobby.
  static let aqua = Color(red: 0.20, green: 0.80, blue: 0.93)
  /// The deeper blue that aqua runs into on glossy surfaces.
  static let sky = Color(red: 0.10, green: 0.48, blue: 0.90)
  /// "Live", "active", good news.
  static let leaf = Color(red: 0.50, green: 0.88, blue: 0.46)
  /// The two tones of a glossy button, dark enough for white text on top.
  static let buttonTop = Color(red: 0.05, green: 0.52, blue: 0.74)
  static let buttonBottom = Color(red: 0.06, green: 0.36, blue: 0.78)
}

/// The background of a screen: a dark blue gradient with three soft lights
/// (aqua top left, blue on the right, green at the bottom). Nothing moves, so
/// it costs no battery.
struct AeroBackground: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [AeroTheme.abyss, AeroTheme.ocean, AeroTheme.abyss],
        startPoint: .top,
        endPoint: .bottom
      )
      RadialGradient(
        colors: [AeroTheme.aqua.opacity(0.34), .clear],
        center: .topLeading,
        startRadius: 0,
        endRadius: 420
      )
      RadialGradient(
        colors: [AeroTheme.sky.opacity(0.22), .clear],
        center: UnitPoint(x: 1.05, y: 0.38),
        startRadius: 0,
        endRadius: 300
      )
      RadialGradient(
        colors: [AeroTheme.leaf.opacity(0.16), .clear],
        center: UnitPoint(x: 0.2, y: 1.05),
        startRadius: 0,
        endRadius: 380
      )
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}

/// A pane of glass for a group of content: frosted, with a bright upper edge
/// and a soft shadow, so it seems to float over the background.
struct AeroCardModifier: ViewModifier {
  var cornerRadius: CGFloat = 20

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    content
      .background(.ultraThinMaterial, in: shape)
      .overlay(
        // The gloss: light falling on the upper part of the pane.
        shape
          .fill(
            LinearGradient(
              colors: [.white.opacity(0.10), .white.opacity(0.02), .clear],
              startPoint: .top,
              endPoint: .center
            )
          )
          .allowsHitTesting(false)
      )
      .overlay(
        shape
          .strokeBorder(
            LinearGradient(
              colors: [.white.opacity(0.50), .white.opacity(0.08)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 1
          )
          .allowsHitTesting(false)
      )
      .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
  }
}

extension View {
  func aeroCard(cornerRadius: CGFloat = 20) -> some View {
    modifier(AeroCardModifier(cornerRadius: cornerRadius))
  }
}

/// The main action of a screen: a glossy aqua button. One per screen; the
/// other actions use `LiquidGlassButtonStyle`.
struct AeroGlossButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    AeroGlossButtonBody(configuration: configuration)
  }
}

private struct AeroGlossButtonBody: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    configuration.label
      .fontWeight(.semibold)
      .foregroundStyle(.white)
      .padding(.vertical, 10)
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity, alignment: .center)
      .background(
        LinearGradient(
          colors: [AeroTheme.buttonTop, AeroTheme.buttonBottom],
          startPoint: .top,
          endPoint: .bottom
        ),
        in: shape
      )
      .overlay(
        // The gloss on the upper half.
        shape
          .fill(
            LinearGradient(
              colors: [.white.opacity(0.38), .white.opacity(0.06), .clear],
              startPoint: .top,
              endPoint: .center
            )
          )
          .allowsHitTesting(false)
      )
      .overlay(
        shape
          .strokeBorder(.white.opacity(0.45), lineWidth: 1)
          .allowsHitTesting(false)
      )
      .shadow(color: AeroTheme.aqua.opacity(isEnabled ? 0.45 : 0), radius: 10, x: 0, y: 4)
      .saturation(isEnabled ? 1 : 0.3)
      .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
  }
}

struct LiquidGlassButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .fontWeight(.semibold)
      .padding(.vertical, 10)
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity, alignment: .center)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [
                .white.opacity(0.85),
                .white.opacity(0.15)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      )
      .shadow(color: .white.opacity(0.16), radius: 8, x: 0, y: 3)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .opacity(configuration.isPressed ? 0.9 : 1)
      .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
  }
}

struct GlassProminentButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .fontWeight(.semibold)
      .padding(.vertical, 10)
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity, alignment: .center)
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [
                .white.opacity(configuration.isPressed ? 0.9 : 0.75),
                .white.opacity(configuration.isPressed ? 0.45 : 0.22)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1.3
          )
      )
      .shadow(color: .white.opacity(configuration.isPressed ? 0.1 : 0.2), radius: 9, x: 0, y: 4)
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.86 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

struct LiquidGlassActionButton: View {
  let title: String
  let isDisabled: Bool
  let role: ButtonRole?
  let action: () -> Void

  init(
    _ title: String,
    isDisabled: Bool = false,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.isDisabled = isDisabled
    self.role = role
    self.action = action
  }

  var body: some View {
    Button(role: role, action: action) {
      Text(title)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(LiquidGlassButtonStyle())
    .disabled(isDisabled)
  }
}
