import SwiftUI
import UIKit

// MARK: - Scroll minimize (legacy tab bar)

@Observable
final class ProcessTabBarScrollState {
    var isMinimized = false

    private var lastOffset: CGFloat = 0
    private var accumulatedDown: CGFloat = 0
    private var accumulatedUp: CGFloat = 0

    func reset() {
        isMinimized = false
        lastOffset = 0
        accumulatedDown = 0
        accumulatedUp = 0
    }

    func update(offset: CGFloat) {
        let delta = offset - lastOffset
        lastOffset = offset

        guard abs(delta) > 0.5 else { return }

        if delta < 0 {
            accumulatedDown += abs(delta)
            accumulatedUp = 0
            if accumulatedDown > 28, offset < -12 {
                withAnimation(ProcessGlass.spring) {
                    isMinimized = true
                }
            }
        } else {
            accumulatedUp += delta
            accumulatedDown = 0
            if accumulatedUp > 18 {
                withAnimation(ProcessGlass.spring) {
                    isMinimized = false
                }
            }
        }
    }
}

struct ProcessMainScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    @ViewBuilder
    func processReportsTabBarScrollOffset() -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ProcessMainScrollOffsetKey.self,
                        value: proxy.frame(in: .named("processMainScroll")).minY
                    )
                }
            )
        }
    }
}

private enum BevelTabMetrics {
    static let horizontalInset: CGFloat = 16
    static let bottomInset: CGFloat = 8
    static let clusterSpacing: CGFloat = 10
    static let tabCapsuleHeight: CGFloat = 52
    static let compactHeight: CGFloat = 50
    static let plusSize: CGFloat = 50
    static let accessoryHeight: CGFloat = 48
    static let protocolSetupAccessoryHeight: CGFloat = 56
    static let protocolSetupInlineHeight: CGFloat = 50
    static let tabIconSize: CGFloat = 22
    static let selectedCornerRadius: CGFloat = 14
    static let coachGlyphSize: CGFloat = 28

    static func coachAccessoryHeight(isProtocolSetup: Bool, inline: Bool) -> CGFloat {
        if isProtocolSetup {
            return inline ? protocolSetupInlineHeight : protocolSetupAccessoryHeight
        }
        return accessoryHeight
    }
}

// MARK: - Coach accessory (Bevel « Demander à … »)

private enum ProcessCoachAccessoryCopy {
    /// Au-dessus de la tab bar (accessory expanded).
    static let expanded = "Posez votre question à Process"
    /// Inline avec la tab bar réduite.
    static let inline = "Demandez à Process"
}


private struct ProcessCoachTabAccessoryContent: View {
    let namespace: Namespace.ID
    let prompt: String
    var isInlinePlacement: Bool = false
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                coachLogo

                Text(prompt)
                    .font(.system(size: isInlinePlacement ? 15 : 16, weight: .medium))
                    .foregroundStyle(isInlinePlacement ? theme.secondaryText : theme.primaryText.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, isInlinePlacement ? 12 : 16)
            .frame(height: BevelTabMetrics.accessoryHeight)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.processPlain)
        .modifier(ProcessCoachAccessoryChrome(isInline: isInlinePlacement))
        .matchedTransitionSource(id: ProcessCoachZoomTransition.sourceID, in: namespace)
        .accessibilityLabel(prompt)
    }

    private var coachLogo: some View {
        Image("caochiaicon")
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            .clipShape(Circle())
    }
}

/// Glass capsule — aligné sur la tab bar IG flottante.
private struct ProcessCoachAccessoryChrome: ViewModifier {
    var isInline: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(ProcessGlass.regular, in: Capsule())
        } else {
            content.processGlassEffect(in: Capsule(style: .continuous), interactive: !isInline)
        }
    }
}
