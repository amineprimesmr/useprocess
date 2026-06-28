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
    func processReportsTabBarScrollOffset() -> some View {
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

private enum BevelTabMetrics {
    static let horizontalInset: CGFloat = 16
    static let bottomInset: CGFloat = 8
    static let clusterSpacing: CGFloat = 10
    static let tabCapsuleHeight: CGFloat = 52
    static let compactHeight: CGFloat = 50
    static let plusSize: CGFloat = 50
    static let accessoryHeight: CGFloat = 48
    static let tabIconSize: CGFloat = 22
    static let selectedCornerRadius: CGFloat = 14
    static let coachGlyphSize: CGFloat = 28
}

// MARK: - Coach accessory (Bevel « Demander à … »)

private enum ProcessCoachAccessoryCopy {
    /// Au-dessus de la tab bar (accessory expanded).
    static let expanded = "Posez votre question à Process"
    /// Inline avec la tab bar réduite.
    static let inline = "Demandez à Process"
}

struct ProcessCoachTabAccessory: View {
    var namespace: Namespace.ID
    var isInlinePlacement: Bool = false
    var onTap: () -> Void

    private var prompt: String {
        isInlinePlacement ? ProcessCoachAccessoryCopy.inline : ProcessCoachAccessoryCopy.expanded
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            ProcessCoachTabAccessoryIOS26(namespace: namespace, onTap: onTap)
        } else {
            ProcessCoachTabAccessoryContent(
                namespace: namespace,
                prompt: prompt,
                isInlinePlacement: isInlinePlacement,
                onTap: onTap
            )
        }
    }
}

@available(iOS 26.0, *)
private struct ProcessCoachTabAccessoryIOS26: View {
    let namespace: Namespace.ID
    let onTap: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var accessoryPlacement

    var body: some View {
        ProcessCoachTabAccessoryContent(
            namespace: namespace,
            prompt: accessoryPlacement == .inline
                ? ProcessCoachAccessoryCopy.inline
                : ProcessCoachAccessoryCopy.expanded,
            isInlinePlacement: accessoryPlacement == .inline,
            onTap: onTap
        )
    }
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
        .buttonStyle(.plain)
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

/// Glass aligné sur la tab bar — iOS 26 : pas de couche custom (teinte système).
private struct ProcessCoachAccessoryChrome: ViewModifier {
    var isInline: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else if isInline {
            content
        } else {
            content.processGlassEffect(in: Capsule(), interactive: false)
        }
    }
}

// MARK: - Legacy floating shell (iOS 18–25)

struct ProcessBevelLegacyTabShell<Content: View>: View {
    @Binding var selectedSection: ProcessMainSection
    var coachZoomNamespace: Namespace.ID
    let isWelcomePlanGating: Bool
    let onPresentCoach: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.appTheme) private var theme
    @State private var scrollState = ProcessTabBarScrollState()

    private var showsChrome: Bool {
        !isWelcomePlanGating
    }

    private var chromeBottomInset: CGFloat {
        guard showsChrome else { return 0 }
        if scrollState.isMinimized {
            return BevelTabMetrics.compactHeight + BevelTabMetrics.bottomInset + UIApplication.safeAreaBottom + 12
        }
        return BevelTabMetrics.accessoryHeight
            + BevelTabMetrics.clusterSpacing
            + BevelTabMetrics.tabCapsuleHeight
            + BevelTabMetrics.bottomInset
            + UIApplication.safeAreaBottom
            + 16
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content()
                .padding(.bottom, chromeBottomInset)
                .environment(scrollState)
                .onPreferenceChange(ProcessMainScrollOffsetKey.self) { offset in
                    scrollState.update(offset: offset)
                }
                .onChange(of: selectedSection) { _, _ in
                    scrollState.reset()
                }

            if showsChrome {
                legacyChrome
                    .padding(.horizontal, BevelTabMetrics.horizontalInset)
                    .padding(.bottom, BevelTabMetrics.bottomInset + UIApplication.safeAreaBottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var legacyChrome: some View {
        if scrollState.isMinimized {
            compactChrome
        } else {
            expandedChrome
        }
    }

    private var expandedChrome: some View {
        VStack(spacing: BevelTabMetrics.clusterSpacing) {
            ProcessCoachTabAccessory(
                namespace: coachZoomNamespace,
                isInlinePlacement: false,
                onTap: onPresentCoach
            )
            legacyTabCapsule
        }
    }

    private var compactChrome: some View {
        HStack(spacing: BevelTabMetrics.clusterSpacing) {
            legacySingleTabButton(for: selectedSection.isShellTab ? selectedSection : .plan)
            ProcessCoachTabAccessory(
                namespace: coachZoomNamespace,
                isInlinePlacement: true,
                onTap: onPresentCoach
            )
        }
    }

    private var legacyTabCapsule: some View {
        HStack(spacing: 0) {
            ForEach(ProcessMainSection.tabOrder) { section in
                legacyTabItem(section)
            }
        }
        .frame(height: BevelTabMetrics.tabCapsuleHeight)
        .frame(maxWidth: .infinity)
        .processGlassEffect(
            in: RoundedRectangle(cornerRadius: 26, style: .continuous),
            interactive: false
        )
    }

    @ViewBuilder
    private func legacyTabItem(_ section: ProcessMainSection) -> some View {
        let isSelected = selectedSection == section
        let tabShape = RoundedRectangle(cornerRadius: BevelTabMetrics.selectedCornerRadius, style: .continuous)

        Button {
            withAnimation(ProcessGlass.spring) {
                selectedSection = section
            }
        } label: {
            legacyTabLabel(section: section, isSelected: isSelected, tabShape: tabShape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.label)
    }

    private func legacyTabLabel(
        section: ProcessMainSection,
        isSelected: Bool,
        tabShape: RoundedRectangle
    ) -> some View {
        ProcessMainTabIcon(section: section, size: BevelTabMetrics.tabIconSize, isSelected: isSelected)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background {
                if isSelected {
                    tabShape
                        .fill(theme.primaryText.opacity(0.07))
                        .padding(8)
                }
            }
    }

    private func legacySingleTabButton(for section: ProcessMainSection) -> some View {
        Button {
            withAnimation(ProcessGlass.spring) {
                selectedSection = section
            }
        } label: {
            ProcessMainTabIcon(section: section, size: 20, isSelected: true)
                .frame(width: BevelTabMetrics.plusSize, height: BevelTabMetrics.plusSize)
        }
        .buttonStyle(.plain)
        .processGlassCircle(interactive: true)
        .accessibilityLabel(section.label)
    }
}
