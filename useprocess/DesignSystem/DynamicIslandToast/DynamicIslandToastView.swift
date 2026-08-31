import SwiftUI

extension View {
    @ViewBuilder
    func dynamicIslandToast(
        isPresented: Binding<Bool>,
        value: DynamicIslandToastMessage,
        onTap: @escaping () -> Void = {}
    ) -> some View {
        modifier(DynamicIslandToastViewModifier(isPresented: isPresented, value: value, onTap: onTap))
    }
}

private struct DynamicIslandToastViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    var value: DynamicIslandToastMessage
    var onTap: () -> Void

    @State private var overlayWindow: DynamicIslandPassThroughWindow?
    @State private var overlayController: DynamicIslandToastHostingController?
    @State private var pendingPresentation = false

    func body(content: Content) -> some View {
        content
            .background(WindowExtractor { mainWindow in
                createOverlayWindow(mainWindow)
            })
            .onChange(of: isPresented, initial: true) { _, newValue in
                applyPresentation(newValue)
            }
            .onChange(of: value.id) { _, _ in
                overlayWindow?.toast = value
            }
    }

    private func applyPresentation(_ presented: Bool) {
        guard let overlayWindow else {
            if presented {
                pendingPresentation = true
            }
            return
        }

        pendingPresentation = false
        overlayWindow.onToastTap = onTap
        overlayWindow.onDismissRequest = { isPresented = false }
        overlayWindow.isUserInteractionEnabled = presented
        if presented {
            overlayWindow.toast = value
        }
        overlayWindow.isPresented = presented
        overlayController?.isStatusBarHidden = presented
    }

    private func createOverlayWindow(_ mainWindow: UIWindow) {
        guard let windowScene = mainWindow.windowScene else { return }

        if let window = windowScene.windows.first(where: { $0.tag == 1009 }) as? DynamicIslandPassThroughWindow {
            overlayWindow = window
            overlayController = window.rootViewController as? DynamicIslandToastHostingController
            if pendingPresentation || isPresented {
                applyPresentation(isPresented)
            }
            return
        }

        let overlayWindow = DynamicIslandPassThroughWindow(windowScene: windowScene)
        overlayWindow.backgroundColor = .clear
        overlayWindow.isHidden = false
        overlayWindow.isUserInteractionEnabled = false
        overlayWindow.tag = 1009
        createRootController(overlayWindow)
        self.overlayWindow = overlayWindow
        if pendingPresentation || isPresented {
            applyPresentation(isPresented)
        }
    }

    private func createRootController(_ window: DynamicIslandPassThroughWindow) {
        let hostingController = DynamicIslandToastHostingController(
            rootView: DynamicIslandToastContentView(window: window)
        )
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController
        overlayController = hostingController
    }
}

struct DynamicIslandToastContentView: View {
    var window: DynamicIslandPassThroughWindow

    private enum Metrics {
        static let cornerRadius: CGFloat = 18
        static let borderOpacity: CGFloat = 0.22
        static let borderWidth: CGFloat = 0.75
        static let collapsedWidth: CGFloat = 126
        static let collapsedHeight: CGFloat = 44
        static let expandedHeightDynamicIsland: CGFloat = 152
        static let expandedHeightLegacy: CGFloat = 112
    }

    var body: some View {
        GeometryReader { proxy in
            let safeArea = proxy.safeAreaInsets
            let size = proxy.size
            let haveDynamicIsland = safeArea.top >= 59
            let dynamicIslandWidth = Metrics.collapsedWidth
            let dynamicIslandHeight = Metrics.collapsedHeight
            let topOffset: CGFloat = 9 + max((safeArea.top - 59), 0)
            let expandedWidth = size.width - 20
            let expandedHeight: CGFloat = haveDynamicIsland
                ? Metrics.expandedHeightDynamicIsland
                : Metrics.expandedHeightLegacy
            let scaleX: CGFloat = isExpanded ? 1 : (dynamicIslandWidth / expandedWidth)
            let scaleY: CGFloat = isExpanded ? 1 : (dynamicIslandHeight / expandedHeight)

            ZStack(alignment: .top) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.shared.impact(.light)
                        window.requestDismiss()
                    }

                toastCapsule(
                    haveDynamicIsland: haveDynamicIsland,
                    expandedWidth: expandedWidth,
                    expandedHeight: expandedHeight,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    dynamicIslandWidth: dynamicIslandWidth,
                    dynamicIslandHeight: dynamicIslandHeight,
                    topOffset: topOffset,
                    safeArea: safeArea
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .animation(.bouncy(duration: 0.3, extraBounce: 0), value: isExpanded)
        }
    }

    @ViewBuilder
    private func toastCapsule(
        haveDynamicIsland: Bool,
        expandedWidth: CGFloat,
        expandedHeight: CGFloat,
        scaleX: CGFloat,
        scaleY: CGFloat,
        dynamicIslandWidth: CGFloat,
        dynamicIslandHeight: CGFloat,
        topOffset: CGFloat,
        safeArea: EdgeInsets
    ) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                ConcentricRectangle(
                    corners: .concentric(minimum: .fixed(Metrics.cornerRadius)),
                    isUniform: true
                )
                .fill(.black)
            } else {
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .fill(.black)
            }
        }
        .overlay {
            toastContent(haveDynamicIsland)
                .frame(width: expandedWidth, height: expandedHeight)
                .scaleEffect(x: scaleX, y: scaleY)
        }
        .overlay {
            toastBorder
        }
        .frame(
            width: isExpanded ? expandedWidth : dynamicIslandWidth,
            height: isExpanded ? expandedHeight : dynamicIslandHeight
        )
        .offset(
            y: haveDynamicIsland ? topOffset : (isExpanded ? safeArea.top + 10 : -80)
        )
        .opacity(haveDynamicIsland ? 1 : (isExpanded ? 1 : 0))
        .animation(.linear(duration: 0.02).delay(isExpanded ? 0 : 0.28)) { content in
            content.opacity(haveDynamicIsland ? (isExpanded ? 1 : 0) : 1)
        }
        .geometryGroup()
        .contentShape(.rect)
        .highPriorityGesture(
            TapGesture().onEnded {
                HapticManager.shared.impact(.light)
                window.onToastTap?()
                window.requestDismiss()
            }
        )
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height < 0 {
                    window.requestDismiss()
                }
            }
        )
    }

    @ViewBuilder
    private var toastBorder: some View {
        if #available(iOS 26.0, *) {
            ConcentricRectangle(
                corners: .concentric(minimum: .fixed(Metrics.cornerRadius)),
                isUniform: true
            )
            .stroke(
                Color.white.opacity(Metrics.borderOpacity),
                lineWidth: Metrics.borderWidth
            )
        } else {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(Metrics.borderOpacity), lineWidth: Metrics.borderWidth)
        }
    }

    @ViewBuilder
    private func toastContent(_ haveDynamicIsland: Bool) -> some View {
        if let toast = window.toast {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: toast.symbol)
                    .font(toast.symbolFont)
                    .foregroundStyle(toast.symbolForegroundStyle.0, toast.symbolForegroundStyle.1)
                    .symbolEffect(.bounce, value: isExpanded)
                    .frame(width: 46)

                VStack(alignment: .leading, spacing: 6) {
                    if haveDynamicIsland {
                        Spacer(minLength: 0)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(toast.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)

                        if toast.streakAfter != nil {
                            Spacer(minLength: 0)
                            DynamicIslandStreakCounter(toast: toast, isExpanded: isExpanded)
                        }
                    }

                    Text(toast.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    if let progress = toast.streakProgress {
                        DynamicIslandStreakProgressBar(progress: progress, isExpanded: isExpanded)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, haveDynamicIsland ? 18 : 8)
                .lineLimit(3)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .compositingGroup()
            .blur(radius: isExpanded ? 0 : 5)
            .opacity(isExpanded ? 1 : 0)
        }
    }

    private var isExpanded: Bool {
        window.isPresented
    }
}

/// Compteur de série X → Y — s'anime après l'apparition du toast.
private struct DynamicIslandStreakCounter: View {
    let toast: DynamicIslandToastMessage
    let isExpanded: Bool

    @State private var displayedValue: Int = 0

    var body: some View {
        Text("\(displayedValue)")
            .font(.title3.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(ProcessStreakPalette.flame)
            .contentTransition(.numericText())
            .onChange(of: toast.id, initial: true) { _, _ in
                displayedValue = toast.streakBefore ?? toast.streakAfter ?? 0
            }
            .onChange(of: isExpanded) { _, expanded in
                guard expanded, let target = toast.streakAfter else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    HapticManager.shared.impact(.light)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        displayedValue = target
                    }
                }
            }
    }
}

/// Barre de progression vers le prochain palier de série.
private struct DynamicIslandStreakProgressBar: View {
    let progress: Double
    let isExpanded: Bool

    @State private var fillFraction: CGFloat = 0

    var body: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.14))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule(style: .continuous)
                        .fill(ProcessStreakPalette.flame)
                        .frame(width: proxy.size.width * fillFraction)
                }
            }
            .clipShape(Capsule(style: .continuous))
            .onChange(of: isExpanded, initial: true) { _, expanded in
                guard expanded else {
                    fillFraction = 0
                    return
                }
                fillFraction = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        fillFraction = CGFloat(progress)
                    }
                }
            }
    }
}
