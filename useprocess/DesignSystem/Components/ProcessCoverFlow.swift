import SwiftUI

/// Cover Flow horizontal — inspiré de iPCoverflow (Balaji Venkatesh).
/// Rotation 3D + offset pilotés par la position réelle dans le `ScrollView`.
struct ProcessCoverFlowConfig: Sendable {
    var cardWidth: CGFloat
    /// Hauteur explicite de la carte. Si nil, remplit le conteneur (comportement legacy).
    var cardHeight: CGFloat? = nil
    var rotation: CGFloat = 52
    var offsetFactor: CGFloat = 1.4
    var activeElevation: CGFloat = 0
    var sideOpacity: Double = 0.52
    var sideScaleMinimum: CGFloat = 0.82
    /// Espace horizontal entre les cartes dans le scroll (cover flow).
    var cardSpacing: CGFloat = 0
    /// Pousse les cartes latérales loin du centre (pt par « pas » de scroll). Compense le tirage cover-flow.
    var sideSpread: CGFloat = 0
    /// Au-delà de ±1 « carte », on cache — une seule voisine visible par côté.
    var maxSideVisibleProgress: CGFloat = 1.08
    /// Limite le swipe manuel à une carte par geste (dashboard preview).
    var limitsScrollToOneCard: Bool = false
}

enum ProcessCoverFlowMotion {
    static let advance = Animation.spring(response: 0.44, dampingFraction: 0.92, blendDuration: 0)
}

struct ProcessCoverFlow<Card: View>: View {
    var config: ProcessCoverFlowConfig
    @Binding var activeIndex: Int?
    let itemCount: Int
    var onFocusedIndexChange: ((Int) -> Void)? = nil
    var onScrollIdle: ((Int?) -> Void)?
    @ViewBuilder var card: (Int, Bool) -> Card

    var body: some View {
        GeometryReader { geo in
            let containerSize = geo.size
            let currentIndex = activeIndex ?? 0
            let resolvedCardHeight = config.cardHeight ?? containerSize.height

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: config.cardSpacing) {
                    ForEach(0..<itemCount, id: \.self) { index in
                        let isFocused = currentIndex == index
                        let zIndex = currentIndex > index ? Double(index) : Double(-index)

                        card(index, isFocused)
                            .frame(width: config.cardWidth, height: resolvedCardHeight)
                            .frame(height: containerSize.height)
                            .visualEffect { content, proxy in
                                let values = layoutAdjustmentValues(
                                    proxy: proxy,
                                    config: config
                                )
                                let absProgress = abs(values.progress)
                                let sideAmount = min(absProgress, 1)
                                let scale = 1 - sideAmount * (1 - config.sideScaleMinimum)
                                var opacity = 1 - sideAmount * (1 - config.sideOpacity)

                                if absProgress > config.maxSideVisibleProgress {
                                    opacity = 0
                                } else if absProgress > 1 {
                                    let fade = (config.maxSideVisibleProgress - absProgress)
                                        / max(config.maxSideVisibleProgress - 1, 0.01)
                                    opacity *= Double(max(0, min(1, fade)))
                                }

                                return content
                                    .scaleEffect(scale)
                                    .opacity(opacity)
                                    .rotation3DEffect(
                                        .degrees(values.rotation),
                                        axis: (x: 0, y: 1, z: 0),
                                        anchor: values.anchor,
                                        anchorZ: values.anchorZ,
                                        perspective: 1
                                    )
                                    .offset(x: values.offset)
                            }
                            .zIndex(isFocused ? 1_000 : zIndex)
                    }
                }
                .scrollTargetLayout()
            }
            .safeAreaPadding(.horizontal, max(0, (containerSize.width - config.cardWidth) / 2))
            .scrollPosition(id: $activeIndex, anchor: .center)
            .scrollTargetBehavior(
                config.limitsScrollToOneCard
                    ? .viewAligned(limitBehavior: .alwaysByOne)
                    : .viewAligned
            )
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .clipped()
            .onScrollGeometryChange(for: Int.self) { geo in
                let stride = max(config.cardWidth + config.cardSpacing, 1)
                let offset = geo.contentOffset.x + geo.contentInsets.leading
                let index = Int((offset / stride).rounded())
                return min(max(index, 0), max(itemCount - 1, 0))
            } action: { _, newIndex in
                onFocusedIndexChange?(newIndex)
            }
            .onChange(of: activeIndex) { _, newValue in
                guard let newValue else { return }
                onFocusedIndexChange?(newValue)
            }
            .onScrollPhaseChange { _, phase in
                guard phase == .idle else { return }
                onScrollIdle?(activeIndex)
            }
        }
    }

    nonisolated
    private func layoutAdjustmentValues(
        proxy: GeometryProxy,
        config: ProcessCoverFlowConfig
    ) -> (rotation: CGFloat, anchor: UnitPoint, anchorZ: CGFloat, offset: CGFloat, progress: CGFloat, cappedProgress: CGFloat) {
        let minX = proxy.frame(in: .scrollView(axis: .horizontal)).minX
        let stride = max(config.cardWidth + config.cardSpacing, 1)
        let progress = minX / stride
        let cappedProgress = max(-1, min(1, progress))

        let rotation = -cappedProgress * config.rotation
        let centerPull = -progress * (config.cardWidth / config.offsetFactor)
        let spread = progress * config.sideSpread
        let offset = centerPull + spread
        let anchor: UnitPoint = cappedProgress < 0 ? .leading : .trailing
        let anchorZ = abs(cappedProgress) * config.activeElevation

        return (rotation, anchor, anchorZ, offset, progress, cappedProgress)
    }
}
