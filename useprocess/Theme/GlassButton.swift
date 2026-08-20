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

struct OnboardingContinueFillRevealLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let progress: Double

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    private var isUnlocked: Bool {
        clampedProgress >= 0.999
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let fillWidth = width * clampedProgress
            let leadingRadius = min(height / 2, max(fillWidth, 0))

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackColor)

                fillLayer(
                    fillWidth: fillWidth,
                    height: height,
                    leadingRadius: leadingRadius
                )
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                fillRevealTitle(fillWidth: fillWidth, totalWidth: width)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .animation(reduceMotion ? nil : .linear(duration: 0.09), value: clampedProgress)
    }

    @ViewBuilder
    private func fillLayer(fillWidth: CGFloat, height: CGFloat, leadingRadius: CGFloat) -> some View {
        if isUnlocked {
            Capsule(style: .continuous)
                .fill(Color.white)
        } else if fillWidth > 0.5 {
            UnevenRoundedRectangle(
                topLeadingRadius: leadingRadius,
                bottomLeadingRadius: leadingRadius,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.white)
            .frame(width: fillWidth, height: height, alignment: .leading)
        }
    }

    @ViewBuilder
    private func fillRevealTitle(fillWidth: CGFloat, totalWidth: CGFloat) -> some View {
        let clampedFill = min(max(fillWidth, 0), totalWidth)
        let unfilledWidth = max(0, totalWidth - clampedFill)

        ZStack {
            Text(title)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(unfilledTextColor)
                .mask(alignment: .trailing) {
                    Rectangle()
                        .frame(width: unfilledWidth)
                }

            Text(title)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(filledTextColor)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: clampedFill)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var trackColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.88)
    }

    private var unfilledTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.72)
            : Color.white.opacity(0.88)
    }

    private var filledTextColor: Color {
        .black
    }
}

struct OnboardingContinueFillRevealButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    let isUnlocked: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Capsule())
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? (isUnlocked ? 0.35 : 0.12) : 0.14),
                radius: configuration.isPressed ? 8 : (isUnlocked ? 12 : 6),
                y: configuration.isPressed ? 2 : 4
            )
            .opacity(configuration.isPressed && isUnlocked ? 0.92 : 1)
            .scaleEffect(configuration.isPressed && isUnlocked ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
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
