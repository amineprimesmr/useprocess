import SwiftUI
import UIKit

// MARK: - Metrics

enum ProcessIGTabMetrics {
    static let tabBarHeight: CGFloat = 50
    static let horizontalInset: CGFloat = 20
    static let chromePadding: CGFloat = 4
    static let clusterSpacing: CGFloat = 10
    static let iconSize: CGFloat = 24
    /// Hauteur totale d’un cluster tab bar (contenu + padding glass).
    static var chromeOuterSize: CGFloat {
        tabBarHeight + (chromePadding * 2)
    }
    /// Marge au-dessus de l’indicateur d’accueil (tab bar flottante).
    static let tabBarBottomInset: CGFloat = 0
    static let collapseDistance: CGFloat = 100
    static let minScale: CGFloat = 0.85

    static var tabBarOverlayClearance: CGFloat {
        tabBarHeight + (chromePadding * 2) + tabBarBottomInset + UIApplication.safeAreaBottom
    }

    static func chromeHeight(hasCompletedWelcomePlan: Bool) -> CGFloat {
        tabBarHeight + (chromePadding * 2) + tabBarBottomInset
    }

    static var collapseAnimation: Animation {
        .interpolatingSpring(duration: 0.25, bounce: 0, initialVelocity: 0)
    }
}

// MARK: - Progress environment

private struct ProcessIGTabBarProgressKey: EnvironmentKey {
    static let defaultValue: Binding<CGFloat>? = nil
}

extension EnvironmentValues {
    var processIGTabBarProgress: Binding<CGFloat>? {
        get { self[ProcessIGTabBarProgressKey.self] }
        set { self[ProcessIGTabBarProgressKey.self] = newValue }
    }
}

// MARK: - Scroll tracking (Instagram-style collapse)

extension View {
    /// Suit le scroll pour le collapse IG — no-op hors `ProcessIGTabShell`.
    @ViewBuilder
    func processAdoptForIGTabBar() -> some View {
        modifier(ProcessIGTabBarScrollModifier())
    }

    @ViewBuilder
    func processHideNativeTabBar() -> some View {
        if #available(iOS 18.0, *) {
            toolbarVisibility(.hidden, for: .tabBar)
        } else {
            toolbar(.hidden, for: .tabBar)
        }
    }
}

private struct ProcessIGTabBarScrollModifier: ViewModifier {
    @Environment(\.processIGTabBarProgress) private var progress

    func body(content: Content) -> some View {
        if let progress {
            content.modifier(ProcessIGTabBarScrollTracking(progress: progress))
        } else {
            content
        }
    }
}

private struct ProcessIGTabBarScrollTracking: ViewModifier {
    @Binding var progress: CGFloat

    @GestureState private var isDragging = false
    @State private var isScrolledUp: Bool?
    @State private var shiftOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isLargerContent = false
    @State private var scrollPhase: ScrollPhase = .idle

    private var distance: CGFloat { ProcessIGTabMetrics.collapseDistance }
    private var animation: Animation { ProcessIGTabMetrics.collapseAnimation }

    private var bottomInset: CGFloat {
        ProcessIGTabMetrics.chromeHeight(hasCompletedWelcomePlan: true)
            + UIApplication.safeAreaBottom
    }

    func body(content: Content) -> some View {
        content
            .processHideNativeTabBar()
            .safeAreaPadding(.bottom, bottomInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .scrollView)
                    .updating($isDragging) { _, out, _ in
                        out = true
                    }
                    .onEnded { value in
                        guard scrollPhase != .idle else { return }
                        let velocity = -value.velocity.height / 5
                        let resultOffset = scrollOffset + velocity
                        let rawProgress = (resultOffset - shiftOffset) / distance
                        let clampedProgress = max(0, min(1, rawProgress))

                        withAnimation(animation) {
                            progress = resultOffset > (distance / 2) && isLargerContent
                                ? (clampedProgress > 0.5 ? 1 : 0)
                                : 0
                        }

                        isScrolledUp = nil
                        shiftOffset = scrollOffset - (progress * distance)
                    }
            )
            .onScrollPhaseChange { _, newPhase in
                scrollPhase = newPhase
            }
            .onScrollGeometryChange(for: CGFloat.self, of: {
                $0.contentSize.height - $0.containerSize.height
            }, action: { _, newValue in
                isLargerContent = newValue > 0
            })
            .onScrollGeometryChange(for: CGFloat.self, of: {
                $0.contentOffset.y + $0.contentInsets.top
            }, action: { oldValue, newValue in
                guard isDragging else { return }
                scrollOffset = newValue
                let scrolledUp = oldValue < newValue

                if isScrolledUp != scrolledUp {
                    isScrolledUp = scrolledUp
                    shiftOffset = newValue - (progress * distance)
                }

                let rawProgress = (newValue - shiftOffset) / distance
                let clampedProgress = max(0, min(1, rawProgress))
                progress = clampedProgress
            })
    }
}

// MARK: - UIKit segmented tab bar

struct ProcessIGStyleTabBar: UIViewRepresentable {
    @Binding var selection: ProcessMainSection
    var tabs: [ProcessMainSection] = ProcessMainSection.tabOrder
    var onInteraction: () -> Void

    func makeUIView(context: Context) -> ProcessIGSegmentedControl {
        let images = tabs.compactMap { $0.tabBarUIImage() }
        let control = ProcessIGSegmentedControl(items: images)
        control.selectedSegmentIndex = tabs.firstIndex(of: selection) ?? 0
        control.selectedSegmentTintColor = UIColor.label.withAlphaComponent(0.12)
        control.setTitleTextAttributes([.foregroundColor: UIColor.label], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor.secondaryLabel], for: .normal)
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        control.onTouchBegan = onInteraction

        DispatchQueue.main.async {
            for subview in control.subviews {
                if subview is UIImageView, subview != control.subviews.last {
                    subview.alpha = 0
                }
            }
        }

        return control
    }

    func updateUIView(_ uiView: ProcessIGSegmentedControl, context: Context) {
        let selectedIndex = tabs.firstIndex(of: selection) ?? 0
        if uiView.selectedSegmentIndex != selectedIndex {
            uiView.selectedSegmentIndex = selectedIndex
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: ProcessIGSegmentedControl,
        context: Context
    ) -> CGSize? {
        CGSize(
            width: proposal.replacingUnspecifiedDimensions().width,
            height: ProcessIGTabMetrics.tabBarHeight
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: ProcessIGStyleTabBar

        init(parent: ProcessIGStyleTabBar) {
            self.parent = parent
        }

        @objc
        func valueChanged(_ sender: UISegmentedControl) {
            let tabs = parent.tabs
            guard sender.selectedSegmentIndex >= 0, sender.selectedSegmentIndex < tabs.count else { return }
            let next = tabs[sender.selectedSegmentIndex]
            guard parent.selection != next else { return }
            HapticManager.shared.impact(.light)
            parent.selection = next
        }
    }
}

final class ProcessIGSegmentedControl: UISegmentedControl {
    var onTouchBegan: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        onTouchBegan?()
    }
}

// MARK: - Shell

struct ProcessIGTabShell<Content: View>: View {
    @Binding var selectedSection: ProcessMainSection
    var onMealScan: (() -> Void)? = nil
    var hidesTabChrome: Bool = false
    @ViewBuilder let content: () -> Content

    @Bindable private var tutorialStore = PlanHomeTutorialStore.shared
    @State private var progress: CGFloat = 0
    /// Sous-pages Réglages (prénom, compte, etc.) — masque le tab bar pour ne pas bloquer Enregistrer / clavier.
    @State private var profileSubrouteActive = false

    private var scale: CGFloat {
        1 - (progress * (1 - ProcessIGTabMetrics.minScale))
    }

    private var showsTabChrome: Bool {
        selectedSection != .coach
            && !profileSubrouteActive
            && !hidesTabChrome
            && !tutorialStore.constrainsHomeLayout
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content()
                .environment(\.processIGTabBarProgress, $progress)
                .onPreferenceChange(ProfileSubrouteActiveKey.self) { active in
                    guard selectedSection == .profile else {
                        if profileSubrouteActive {
                            withAnimation(ProcessGlass.spring) {
                                profileSubrouteActive = false
                            }
                        }
                        return
                    }
                    guard profileSubrouteActive != active else { return }
                    withAnimation(ProcessGlass.spring) {
                        profileSubrouteActive = active
                    }
                }

            if showsTabChrome {
                tabBarChrome
                    .padding(.horizontal, ProcessIGTabMetrics.horizontalInset)
                    .padding(.bottom, ProcessIGTabMetrics.tabBarBottomInset)
                    .zIndex(tutorialStore.isActive && tutorialStore.currentStep.isTabStep ? 860 : 100)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
            }
        }
        // Ne pas animer tout le ZStack sur profileSubrouteActive :
        // ça entre en conflit avec le push NavigationStack (pages superposées).
        .animation(ProcessGlass.spring, value: selectedSection == .coach)
        .onChange(of: selectedSection) { _, section in
            if section != .profile {
                profileSubrouteActive = false
            }
            expandIfNeeded()
        }
    }

    /// Bandeau flottant — fond intercepte les taps (évite de toucher le scroll derrière).
    private var tabBarChrome: some View {
        HStack(alignment: .center, spacing: ProcessIGTabMetrics.clusterSpacing) {
            mainTabCluster

            if let onMealScan {
                ProcessIGMealScanButton(
                    action: onMealScan,
                    isInteractionEnabled: !tutorialStore.isActive
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .background {
            Color.clear
                .contentShape(Rectangle())
        }
        .scaleEffect(scale, anchor: .bottom)
        .accessibilityElement(children: .contain)
    }

    private var mainTabCluster: some View {
        ProcessIGStyleTabBar(selection: $selectedSection) {
            expandIfNeeded()
        }
        .frame(height: ProcessIGTabMetrics.tabBarHeight)
        .frame(maxWidth: .infinity)
        .padding(ProcessIGTabMetrics.chromePadding)
        .frame(height: ProcessIGTabMetrics.chromeOuterSize)
        .overlay {
            if tutorialStore.isActive,
               tutorialStore.currentStep.isTabStep,
               let tab = tutorialStore.currentStep.mainTab {
                PlanHomeTutorialTabSegmentOutline(highlightedTab: tab)
            }
        }
        .contentShape(Capsule(style: .continuous))
        .modifier(ProcessIGTabBarGlassChrome(style: .capsule))
        .allowsHitTesting(!tutorialStore.isActive)
    }

    private func expandIfNeeded() {
        guard progress != 0 else { return }
        withAnimation(ProcessIGTabMetrics.collapseAnimation) {
            progress = 0
        }
    }
}

// MARK: - Bouton scan repas (viewfinder)

/// Zone tactile pleine — le glass seul laissait passer les taps vers le scroll derrière.
private struct ProcessIGMealScanButton: View {
    let action: () -> Void
    var isInteractionEnabled: Bool = true

    private var hitSize: CGFloat { ProcessIGTabMetrics.chromeOuterSize + 4 }

    var body: some View {
        Button {
            HapticManager.shared.impact(.medium)
            action()
        } label: {
            Color.clear
                .frame(width: hitSize, height: hitSize)
                .overlay {
                    Image(systemName: "viewfinder")
                        .font(.system(size: ProcessIGTabMetrics.iconSize, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.primary)
                        .frame(
                            width: ProcessIGTabMetrics.tabBarHeight,
                            height: ProcessIGTabMetrics.tabBarHeight
                        )
                }
        }
        .buttonStyle(.processPlain)
        .frame(width: hitSize, height: hitSize)
        .contentShape(Circle())
        .modifier(ProcessIGTabBarGlassChrome(style: .circle))
        .clipShape(Circle())
        .allowsHitTesting(isInteractionEnabled)
        .accessibilityLabel(AppCopy.t("Scanner un repas", en: "Scan a meal"))
        .accessibilityHint(AppCopy.t(
            "Ouvre la caméra ou la pellicule pour analyser ton repas",
            en: "Opens the camera or photo library to analyze your meal"
        ))
    }
}

private struct ProcessIGTabBarGlassChrome: ViewModifier {
    enum Style {
        case capsule
        case circle
    }

    var style: Style = .capsule

    @Environment(\.colorScheme) private var colorScheme

    private var legacyTint: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.22)
            : Color.white.opacity(0.55)
    }

    func body(content: Content) -> some View {
        switch style {
        case .capsule:
            if #available(iOS 26.0, *) {
                content.glassEffect(ProcessGlass.tabBarChrome(for: colorScheme), in: Capsule())
            } else {
                content
                    .processGlassEffect(in: Capsule(style: .continuous), interactive: true)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(legacyTint)
                            .allowsHitTesting(false)
                    }
            }
        case .circle:
            if #available(iOS 26.0, *) {
                content.glassEffect(ProcessGlass.tabBarChrome(for: colorScheme), in: Circle())
            } else {
                content
                    .processGlassEffect(in: Circle(), interactive: true)
                    .overlay {
                        Circle()
                            .fill(legacyTint)
                            .allowsHitTesting(false)
                    }
            }
        }
    }
}
