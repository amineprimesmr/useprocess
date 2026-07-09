import SwiftUI

/// Scène hydratation — contenu coloré derrière, une seule couche eau liquid glass `.clear`.
struct ProcessFluidWaterSceneView<Content: View>: View {
    @ObservedObject var engine: ProcessFluidWaterMotionEngine
    var fillLevel: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            content()

            if #available(iOS 26.0, *) {
                GlassEffectContainer {
                    waterGlassLayer
                }
            } else {
                waterFallbackLayer
            }
        }
        .ignoresSafeArea()
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var waterGlassLayer: some View {
        GeometryReader { _ in
            let glassShape = ProcessFluidWaterShape(
                fillLevel: fillLevel,
                roll: engine.roll,
                pitch: engine.pitch,
                wavePhase: 0
            )

            glassShape
                .fill(.clear)
                .glassEffect(ProcessGlass.waterSurface, in: glassShape)
        }
        .allowsHitTesting(false)
        .transaction { $0.animation = nil }
    }

    @ViewBuilder
    private var waterFallbackLayer: some View {
        GeometryReader { _ in
            let shape = ProcessFluidWaterShape(
                fillLevel: fillLevel,
                roll: engine.roll,
                pitch: engine.pitch,
                wavePhase: engine.wavePhase
            )

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.88, blue: 0.97, opacity: 0.22),
                            Color(red: 0.14, green: 0.62, blue: 0.78, opacity: 0.30)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .allowsHitTesting(false)
        .transaction { $0.animation = nil }
    }
}

// MARK: - Forme

private struct ProcessFluidWaterShape: Shape {
    var fillLevel: CGFloat
    var roll: CGFloat
    var pitch: CGFloat
    var wavePhase: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(fillLevel, wavePhase) }
        set {
            fillLevel = newValue.first
            wavePhase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        ProcessFluidWaterSurface.surfacePath(
            width: rect.width,
            height: rect.height,
            fillLevel: fillLevel,
            roll: roll,
            pitch: pitch,
            wavePhase: wavePhase
        )
    }
}
