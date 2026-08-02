import SwiftUI
import UIKit

// MARK: - Metrics

enum ProcessIGTabMetrics {
    static let tabBarHeight: CGFloat = 50
    static let horizontalInset: CGFloat = 20
    static let chromePadding: CGFloat = 4
    static let clusterSpacing: CGFloat = 10
    /// Marge au-dessus de l’indicateur d’accueil (tab bar flottante).
    static let tabBarBottomInset: CGFloat = 2
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
                DragGesture(minimumDistance: 0, coordinateSpace: .scrollView)
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
                withAnimation(animation) {
                    progress = clampedProgress
                }
            })
    }
}

// MARK: - UIKit segmented tab bar

struct ProcessIGStyleTabBar: UIViewRepresentable {
    @Binding var selection: ProcessMainSection
    var tabs: [ProcessMainSection] = ProcessMainSection.tabOrder
    var onInteraction: () -> Void

    func makeUIView(context: Context) -> ProcessIGSegmentedControl {
        let images = tabs.compactMap { tab -> UIImage? in
            UIImage(systemName: tab.icon)?
                .withConfiguration(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 20, weight: .semibold)))
        }
        let control = ProcessIGSegmentedControl(items: images)
        control.selectedSegmentIndex = tabs.firstIndex(of: selection) ?? 0
        control.selectedSegmentTintColor = UIColor.label.withAlphaComponent(0.12)
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
    @ViewBuilder let content: () -> Content

    @State private var progress: CGFloat = 0

    private var scale: CGFloat {
        1 - (progress * (1 - ProcessIGTabMetrics.minScale))
    }

    var body: some View {
        content()
            .environment(\.processIGTabBarProgress, $progress)
            .overlay(alignment: .bottom) {
                if selectedSection != .coach {
                    chrome
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            )
                        )
                }
            }
            .animation(ProcessGlass.spring, value: selectedSection == .coach)
            .onChange(of: selectedSection) { _, _ in
                expandIfNeeded()
            }
    }

    private var chrome: some View {
        ProcessIGStyleTabBar(selection: $selectedSection) {
            expandIfNeeded()
        }
        .padding(ProcessIGTabMetrics.chromePadding)
        .modifier(ProcessIGTabBarGlassChrome())
        .scaleEffect(scale, anchor: .bottom)
        .padding(.horizontal, ProcessIGTabMetrics.horizontalInset)
        .padding(.bottom, ProcessIGTabMetrics.tabBarBottomInset)
        .accessibilityElement(children: .contain)
    }

    private func expandIfNeeded() {
        guard progress != 0 else { return }
        withAnimation(ProcessIGTabMetrics.collapseAnimation) {
            progress = 0
        }
    }
}

private struct ProcessIGTabBarGlassChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(ProcessGlass.regular, in: Capsule())
        } else {
            content.processGlassEffect(in: Capsule(style: .continuous), interactive: true)
        }
    }
}
