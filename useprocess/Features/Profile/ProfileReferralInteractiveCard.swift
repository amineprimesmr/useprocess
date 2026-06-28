import SwiftUI

/// Carte parrainage — inclinaison 3D + haptiques continues au doigt (style Opal).
struct ProfileReferralInteractiveCard: View {
    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0
    @State private var parallaxX: CGFloat = 0
    @State private var parallaxY: CGFloat = 0
    @State private var isInteracting = false

    private let cardShape = RoundedRectangle(cornerRadius: ProfileTheme.buttonCornerRadius, style: .continuous)
    private let maxTiltDegrees: Double = 13
    private let maxParallax: CGFloat = 9

    var body: some View {
        Image("carteparrainage")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(cardShape)
            .overlay {
                GeometryReader { geo in
                    Color.clear
                        .contentShape(cardShape)
                        .highPriorityGesture(interactionGesture(cardSize: geo.size))
                }
            }
            .scaleEffect(isInteracting ? 1.018 : 1, anchor: .center)
            .offset(x: parallaxX, y: parallaxY)
            .rotation3DEffect(
                .degrees(tiltX),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                perspective: 0.55
            )
            .rotation3DEffect(
                .degrees(tiltY),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.55
            )
            .shadow(
                color: .black.opacity(isInteracting ? 0.28 : 0.14),
                radius: isInteracting ? 22 : 14,
                x: parallaxX * 0.35,
                y: parallaxY * 0.45 + 10
            )
            .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.78), value: isInteracting)
            .onDisappear {
                if isInteracting {
                    endInteraction()
                }
            }
            .accessibilityLabel("Carte parrainage")
            .accessibilityHint("Maintiens et fais glisser pour incliner la carte")
    }

    private func interactionGesture(cardSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard cardSize.width > 1, cardSize.height > 1 else { return }

                if !isInteracting {
                    isInteracting = true
                    HapticManager.shared.beginContinuousCardHold()
                }

                let center = CGPoint(x: cardSize.width * 0.5, y: cardSize.height * 0.5)
                let nx = normalizedFingerDelta(value.location.x - center.x, halfExtent: cardSize.width * 0.5)
                let ny = normalizedFingerDelta(value.location.y - center.y, halfExtent: cardSize.height * 0.5)

                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.84)) {
                    tiltY = nx * maxTiltDegrees
                    tiltX = -ny * maxTiltDegrees
                    parallaxX = nx * maxParallax
                    parallaxY = ny * maxParallax * 0.55
                }
            }
            .onEnded { _ in
                endInteraction()
            }
    }

    private func endInteraction() {
        guard isInteracting else { return }
        isInteracting = false
        HapticManager.shared.endContinuousCardHold()

        withAnimation(.spring(response: 0.52, dampingFraction: 0.74)) {
            tiltX = 0
            tiltY = 0
            parallaxX = 0
            parallaxY = 0
        }
    }

    private func normalizedFingerDelta(_ delta: CGFloat, halfExtent: CGFloat) -> CGFloat {
        guard halfExtent > 0 else { return 0 }
        let raw = delta / halfExtent
        return min(1, max(-1, raw))
    }
}
