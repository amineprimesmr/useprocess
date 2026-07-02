import SwiftUI

extension View {
    @ViewBuilder
    func dynamicIslandToast(isPresented: Binding<Bool>, value: DynamicIslandToastMessage) -> some View {
        modifier(DynamicIslandToastViewModifier(isPresented: isPresented, value: value))
    }
}

private struct DynamicIslandToastViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    var value: DynamicIslandToastMessage

    @State private var overlayWindow: DynamicIslandPassThroughWindow?
    @State private var overlayController: DynamicIslandToastHostingController?

    func body(content: Content) -> some View {
        content
            .background(WindowExtractor { mainWindow in
                createOverlayWindow(mainWindow)
            })
            .onChange(of: isPresented, initial: true) { _, newValue in
                guard let overlayWindow else { return }
                if newValue {
                    overlayWindow.toast = value
                }
                overlayWindow.isPresented = newValue
                overlayController?.isStatusBarHidden = newValue
            }
            .onChange(of: value.id) { _, _ in
                overlayWindow?.toast = value
            }
            .onChange(of: overlayWindow?.isPresented) { _, newValue in
                guard let newValue,
                      let overlayWindow,
                      overlayWindow.toast?.id == value.id,
                      newValue != isPresented else { return }
                isPresented = false
            }
    }

    private func createOverlayWindow(_ mainWindow: UIWindow) {
        guard let windowScene = mainWindow.windowScene else { return }

        if let window = windowScene.windows.first(where: { $0.tag == 1009 }) as? DynamicIslandPassThroughWindow {
            overlayWindow = window
            overlayController = window.rootViewController as? DynamicIslandToastHostingController
            return
        }

        let overlayWindow = DynamicIslandPassThroughWindow(windowScene: windowScene)
        overlayWindow.backgroundColor = .clear
        overlayWindow.isHidden = false
        overlayWindow.isUserInteractionEnabled = true
        overlayWindow.tag = 1009
        createRootController(overlayWindow)
        self.overlayWindow = overlayWindow
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
        static let cornerRadius: CGFloat = 16
        static let collapsedWidth: CGFloat = 126
        static let collapsedHeight: CGFloat = 44
        static let expandedHeightDynamicIsland: CGFloat = 118
        static let expandedHeightLegacy: CGFloat = 86
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

            ZStack {
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
                    .gesture(
                        DragGesture().onEnded { value in
                            if value.translation.height < 0 {
                                window.isPresented = false
                            }
                        }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .animation(.bouncy(duration: 0.3, extraBounce: 0), value: isExpanded)
        }
    }

    @ViewBuilder
    private func toastContent(_ haveDynamicIsland: Bool) -> some View {
        if let toast = window.toast {
            HStack(spacing: 10) {
                Image(systemName: toast.symbol)
                    .font(toast.symbolFont)
                    .foregroundStyle(toast.symbolForegroundStyle.0, toast.symbolForegroundStyle.1)
                    .symbolEffect(.bounce, value: isExpanded)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 5) {
                    if haveDynamicIsland {
                        Spacer(minLength: 0)
                    }

                    Text(toast.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(toast.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, haveDynamicIsland ? 14 : 0)
                .lineLimit(2)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 4)
            .compositingGroup()
            .blur(radius: isExpanded ? 0 : 5)
            .opacity(isExpanded ? 1 : 0)
        }
    }

    private var isExpanded: Bool {
        window.isPresented
    }
}
