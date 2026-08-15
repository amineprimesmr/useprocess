import SwiftUI

/// Effet cover-flow pour carrousels SwiftUI — évite les timeouts du type-checker dans les vues.
enum ProcessScrollCoverFlowEffect {
    nonisolated struct Configuration: Sendable {
        var yRotationDegrees: Double = 22
        var xRotationDegrees: Double = 6
        var scaleReduction: CGFloat = 0.10
        var opacityReduction: Double = 0.30
        var horizontalOffset: CGFloat = 14
        var verticalOffset: CGFloat = 14
        var perspective: CGFloat = 0.46
    }

    nonisolated static func apply(
        _ content: EmptyVisualEffect,
        phase: ScrollTransitionPhase,
        config: Configuration = Configuration()
    ) -> some VisualEffect {
        let t = phase.value
        let absT = abs(t)

        return content
            .rotation3DEffect(
                .degrees(Double(t) * -config.yRotationDegrees),
                axis: (x: 0.05, y: 1, z: 0),
                anchor: .center,
                perspective: config.perspective
            )
            .rotation3DEffect(
                .degrees(Double(absT) * config.xRotationDegrees),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: config.perspective
            )
            .scaleEffect(1 - absT * config.scaleReduction, anchor: .center)
            .opacity(Double(1 - absT * config.opacityReduction))
            .offset(x: t * config.horizontalOffset, y: absT * config.verticalOffset)
    }
}

extension View {
    /// Inclinaison 3D cover-flow pendant le scroll horizontal.
    func processCoverFlowScrollTransition(
        config: ProcessScrollCoverFlowEffect.Configuration = .init()
    ) -> some View {
        scrollTransition(.interactive, axis: .horizontal) { content, phase in
            ProcessScrollCoverFlowEffect.apply(content, phase: phase, config: config)
        }
    }

    /// Scale + légère baisse d’opacité — centre à 1.0, voisines plus petites. Pas de 3D.
    func processFocusScaleScrollTransition(
        scaleReduction: CGFloat = 0.10,
        opacityReduction: Double = 0
    ) -> some View {
        scrollTransition(.interactive, axis: .horizontal) { content, phase in
            let absT = abs(phase.value)
            return content
                .scaleEffect(1 - absT * scaleReduction, anchor: .center)
                .opacity(1 - absT * opacityReduction)
        }
    }
}
