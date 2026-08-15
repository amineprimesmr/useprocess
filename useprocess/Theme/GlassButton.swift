import SwiftUI

/// Feedback tactile visuel standard — scale down au appui (pattern iOS natif).
enum ProcessButtonPressFeedback {
    static let pressedScale: CGFloat = 0.96
    static let animation: Animation = .spring(response: 0.25, dampingFraction: 0.7)
    /// Tap rapide : `isPressed` repasse à false avant la fin du spring — on garde le shrink visible.
    static let minimumPressDuration: TimeInterval = 0.12
}

/// Scale down au press, y compris sur tap court (pas seulement appui long).
struct ProcessButtonPressScaleEffect: ViewModifier {
    let isPressed: Bool

    @State private var showsPress = false
    @State private var releaseGeneration = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(showsPress ? ProcessButtonPressFeedback.pressedScale : 1)
            .animation(ProcessButtonPressFeedback.animation, value: showsPress)
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    releaseGeneration &+= 1
                    showsPress = true
                } else {
                    let generation = releaseGeneration
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + ProcessButtonPressFeedback.minimumPressDuration
                    ) {
                        guard generation == releaseGeneration else { return }
                        showsPress = false
                    }
                }
            }
    }
}

extension View {
    func processButtonPressScale(isPressed: Bool) -> some View {
        modifier(ProcessButtonPressScaleEffect(isPressed: isPressed))
    }
}

struct ProcessPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .processButtonPressScale(isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ProcessPlainButtonStyle {
    static var processPlain: ProcessPlainButtonStyle { ProcessPlainButtonStyle() }
}

private struct GlassFallbackStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Capsule())
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 50))
            .overlay(
                RoundedRectangle(cornerRadius: 50)
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .processButtonPressScale(isPressed: configuration.isPressed)
    }
}

private struct GlassCircleFallbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Circle())
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .processButtonPressScale(isPressed: configuration.isPressed)
    }
}

private struct GlassCapsuleFallbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .processButtonPressScale(isPressed: configuration.isPressed)
    }
}

private struct OnboardingPrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Capsule())
            .background(OnboardingTheme.filledButtonBackground(for: colorScheme), in: Capsule())
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.18),
                radius: configuration.isPressed ? 8 : 12,
                y: configuration.isPressed ? 2 : 4
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
            .processButtonPressScale(isPressed: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func glassStyle() -> some View {
        if #available(iOS 26.0, *) {
            processGlassButton(in: Capsule())
        } else {
            buttonStyle(GlassFallbackStyle())
        }
    }

    @ViewBuilder
    func glassCircleStyle() -> some View {
        if #available(iOS 26.0, *) {
            processGlassButton(in: Circle())
        } else {
            buttonStyle(GlassCircleFallbackStyle())
        }
    }

    @ViewBuilder
    func glassCapsuleStyle() -> some View {
        if #available(iOS 26.0, *) {
            processGlassButton(in: Capsule())
        } else {
            buttonStyle(GlassCapsuleFallbackStyle())
        }
    }

    @ViewBuilder
    func glassProminentCapsuleStyle(tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .buttonSizing(.fitted)
                .tint(tint)
        } else {
            buttonStyle(.plain)
                .background(Capsule().fill(tint))
        }
    }

    func onboardingPrimaryActionStyle() -> some View {
        buttonStyle(OnboardingPrimaryActionButtonStyle())
    }
}
