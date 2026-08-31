import SwiftUI

extension View {
    func processMorphingRefreshable(onRefresh: @escaping () async -> Void) -> some View {
        modifier(ProcessMorphingRefreshableModifier(onRefresh: onRefresh))
    }
}

private struct ProcessMorphingRefreshableModifier: ViewModifier {
    var onRefresh: () async -> Void

    @State private var scrollProgress: CGFloat = 0
    @State private var actualProgress: CGFloat = 0
    @State private var isRefreshing = false
    @State private var isAnimating = false
    @State private var tintColor: Color = .gray
    @State private var canUpdateTint = false
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .background(ProcessRefreshControlTintUpdater(color: $tintColor) {
                canUpdateTint = $0
            })
            .compositingGroup()
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    let safeArea = proxy.safeAreaInsets

                    ZStack {
                        if safeArea.top < 70, scrollProgress != 0, canUpdateTint {
                            morphingView(safeArea)
                        }
                    }
                    .ignoresSafeArea()
                }
                .frame(height: 1)
                .allowsHitTesting(false)
            }
            .mask {
                // Remplissage explicitement opaque : un `Rectangle()` nu hérite du
                // `foregroundStyle` ambiant, et un style non opaque délavait toute
                // la page (texte gris, boutons délavés, images ternes).
                Rectangle()
                    .fill(Color.black)
                    .ignoresSafeArea()
            }
            .refreshable {
                isRefreshing = true
                await onRefresh()

                if actualProgress == 0 {
                    isAnimating = true
                    withAnimation(.easeInOut(duration: 0.2), completionCriteria: .logicallyComplete) {
                        scrollProgress = 0.01
                    } completion: {
                        scrollProgress = 0
                        isAnimating = false
                    }
                }

                isRefreshing = false
            }
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y + $0.contentInsets.top
            } action: { _, newValue in
                let progress = max(min(-newValue / 60, 1), 0)
                actualProgress = progress

                if !isAnimating {
                    scrollProgress = isRefreshing ? 1 : progress
                }
            }
            .onGeometryChange(for: EdgeInsets.self) {
                $0.safeAreaInsets
            } action: { newValue in
                tintColor = newValue.top < 70 ? .clear : .gray
            }
    }

    @ViewBuilder
    private func morphingView(_ safeArea: EdgeInsets) -> some View {
        let hasDynamicIsland = safeArea.top >= 59
        let extraScrollOffset = hasDynamicIsland ? 0 : 15.0
        let topOffset = safeArea.top < 35 ? safeArea.top + 50 : safeArea.top + extraScrollOffset
        let scrollOffset = topOffset * scrollProgress
        let blurRadius = 25.0

        Rectangle()
            .fill(.clear)
            .frame(height: safeArea.top)
            .overlay(alignment: hasDynamicIsland ? .center : .top) {
                Capsule()
                    .fill(.black)
                    .frame(width: 100, height: 33)
                    .opacity(scenePhase == .active ? 1 : 0)
                    .mask {
                        Capsule()
                            .padding(.top, 5)
                    }
                    .overlay(alignment: .bottom) {
                        let indicatorProgress = scrollProgress > 0.2 ? (scrollProgress - 0.2) / 0.8 : 0
                        let indicatorSize = 30 + indicatorProgress * 10

                        Circle()
                            .fill(.black)
                            .frame(width: indicatorSize, height: indicatorSize)
                            .offset(y: scrollOffset)
                    }
                    .compositingGroup()
                    .blur(radius: blurRadius - blurRadius * scrollProgress)
                    .visualEffect { [scrollProgress] content, proxy in
                        content.layerEffect(
                            ShaderLibrary.processRefreshAlphaThreshold(),
                            maxSampleOffset: proxy.size,
                            isEnabled: scrollProgress != 1
                        )
                    }
                    .overlay(alignment: .bottom) {
                        let indicatorSize = 30 + scrollProgress * 10
                        let indicatorOpacity = scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0

                        ProgressView()
                            .tint(.white)
                            .controlSize(.small)
                            .opacity(indicatorOpacity)
                            .frame(width: indicatorSize, height: indicatorSize)
                            .offset(y: scrollOffset)
                    }
                    .offset(y: safeArea.top < 35 ? -35 : 0)
            }
    }
}

private struct ProcessRefreshControlTintUpdater: UIViewRepresentable {
    @Binding var color: Color
    var result: (Bool) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        updateTint(view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        updateTint(uiView)
    }

    private func updateTint(_ view: UIView) {
        DispatchQueue.main.async {
            if let compositingGroup = view.superview?.superview,
               let scrollView = compositingGroup.subviews.last?.subviews.last as? UIScrollView {
                scrollView.refreshControl?.tintColor = UIColor(color)
                result(true)
            } else {
                result(false)
            }
        }
    }
}
