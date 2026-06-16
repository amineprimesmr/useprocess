import SwiftUI

// MARK: - Plat au bord → détachement → rond → 3 points

enum CoachEdgeBlobMode: Equatable {
    case thinking(start: Date)
    case voice(elapsed: TimeInterval, total: TimeInterval)
}

struct CoachEdgeBlobOverlay: View {
    var isDark: Bool
    var mode: CoachEdgeBlobMode

    private var fill: Color { isDark ? .white : .black }

    private let circleRadius: CGFloat = 9
    private let dotRadius: CGFloat = 3.2
    private let dotSpacing: CGFloat = 11
    private let flatHeight: CGFloat = 40
    private let flatProtrusionMin: CGFloat = 0.35
    private let flatProtrusionMax: CGFloat = 0.75
    /// Éloignement max du bord une fois rond.
    private let detachGap: CGFloat = 10

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let frame = resolveFrame(at: timeline.date)

            Canvas { context, size in
                let midY = size.height * 0.5

                switch frame.kind {
                case .flat(let protrusion, let height):
                    let path = flatShape(protrusion: protrusion, height: height, midY: midY)
                    context.fill(path, with: .color(fill.opacity(frame.opacity)))

                case .morph(let protrusion, let roundness, let leadingX):
                    let path = morphShape(
                        protrusion: protrusion,
                        roundness: roundness,
                        leadingX: leadingX,
                        midY: midY
                    )
                    context.fill(path, with: .color(fill.opacity(frame.opacity)))

                case .circle(let radius, let leadingX):
                    let rect = CGRect(
                        x: leadingX,
                        y: midY - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(fill.opacity(frame.opacity))
                    )

                case .dots(let dots):
                    for dot in dots {
                        let rect = CGRect(
                            x: dot.x - dot.radius,
                            y: midY - dot.radius,
                            width: dot.radius * 2,
                            height: dot.radius * 2
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(fill.opacity(dot.opacity * frame.opacity))
                        )
                    }
                }
            }
            .frame(width: 56, height: 72, alignment: .leading)
        }
        .frame(width: 56, height: 72, alignment: .leading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Frame

    private enum FrameKind {
        case flat(protrusion: CGFloat, height: CGFloat)
        case morph(protrusion: CGFloat, roundness: CGFloat, leadingX: CGFloat)
        case circle(radius: CGFloat, leadingX: CGFloat)
        case dots([LoadingDot])
    }

    private struct LoadingDot {
        var x: CGFloat
        var radius: CGFloat
        var opacity: Double
    }

    private struct ResolvedFrame {
        var kind: FrameKind
        var opacity: Double
    }

    private func resolveFrame(at date: Date) -> ResolvedFrame {
        switch mode {
        case .thinking(let start):
            return thinkingFrame(elapsed: date.timeIntervalSince(start))
        case .voice(let elapsed, let total):
            return voiceFrame(elapsed: elapsed, total: max(total, 0.001))
        }
    }

    // Cycle thinking (~3.8 s)
    // 1. Plat collé au bord
    // 2. Détachement + arrondi progressif
    // 3. Rond stable
    // 4. Rond → point + 2 points
    // 5. Animation chargement 3 points

    private func thinkingFrame(elapsed: TimeInterval) -> ResolvedFrame {
        let cycle: TimeInterval = 3.8
        let t = elapsed.truncatingRemainder(dividingBy: cycle)

        // Plat au bord — fin et haut
        if t < 0.35 {
            let p = WaterCurve.easeOut(t / 0.35)
            return ResolvedFrame(
                kind: .flat(
                    protrusion: flatProtrusionMin + (flatProtrusionMax - flatProtrusionMin) * p,
                    height: flatHeight
                ),
                opacity: Double(0.55 + 0.45 * p)
            )
        }

        // Détachement : s'épaissit, s'arrondit et s'éloigne du bord avec l'arrondi
        if t < 1.35 {
            let roundness = WaterCurve.detach((t - 0.35) / 1.0)
            let leadingX = detachGap * WaterCurve.detachLift(roundness)
            return ResolvedFrame(
                kind: .morph(
                    protrusion: flatProtrusionMax + (circleRadius * 2 - flatProtrusionMax) * WaterCurve.widen(roundness),
                    roundness: roundness,
                    leadingX: leadingX
                ),
                opacity: 1
            )
        }

        // Rond détaché du bord
        if t < 1.65 {
            return ResolvedFrame(
                kind: .circle(radius: circleRadius, leadingX: detachGap),
                opacity: 1
            )
        }

        // Le rond devient le 1er point, les 2 autres apparaissent
        if t < 2.05 {
            let p = WaterCurve.easeInOut((t - 1.65) / 0.40)
            return ResolvedFrame(
                kind: .dots(shrinkToThreeDots(progress: p, bouncePhase: 0)),
                opacity: 1
            )
        }

        // Animation de chargement — 3 points qui pulsent
        let bouncePhase = (t - 2.05) / 1.55
        return ResolvedFrame(
            kind: .dots(shrinkToThreeDots(progress: 1, bouncePhase: bouncePhase)),
            opacity: 1
        )
    }

    private func voiceFrame(elapsed: TimeInterval, total: TimeInterval) -> ResolvedFrame {
        let ratio = elapsed / total

        if ratio < 0.10 {
            let p = WaterCurve.easeOut(ratio / 0.10)
            return ResolvedFrame(
                kind: .flat(
                    protrusion: flatProtrusionMin + (flatProtrusionMax - flatProtrusionMin) * p,
                    height: flatHeight
                ),
                opacity: Double(0.6 + 0.4 * p)
            )
        }

        if ratio < 0.28 {
            let roundness = WaterCurve.detach((ratio - 0.10) / 0.18)
            return ResolvedFrame(
                kind: .morph(
                    protrusion: flatProtrusionMax + (circleRadius * 2 - flatProtrusionMax) * WaterCurve.widen(roundness),
                    roundness: roundness,
                    leadingX: detachGap * WaterCurve.detachLift(roundness)
                ),
                opacity: 1
            )
        }

        if ratio < 0.68 {
            let fade = ratio > 0.58 ? WaterCurve.easeIn((ratio - 0.58) / 0.10) : 0
            let bouncePhase = elapsed * 1.4
            return ResolvedFrame(
                kind: .dots(shrinkToThreeDots(progress: 1, bouncePhase: bouncePhase)),
                opacity: Double(1 - fade)
            )
        }

        if ratio < 0.82 {
            let p = WaterCurve.easeIn((ratio - 0.68) / 0.14)
            return ResolvedFrame(
                kind: .morph(
                    protrusion: circleRadius * 2 * (1 - p) + flatProtrusionMin,
                    roundness: 1 - p,
                    leadingX: detachGap * (1 - p)
                ),
                opacity: Double(1 - p * 0.5)
            )
        }

        return ResolvedFrame(
            kind: .flat(protrusion: flatProtrusionMin, height: flatHeight),
            opacity: 0
        )
    }

    private func shrinkToThreeDots(progress: CGFloat, bouncePhase: CGFloat) -> [LoadingDot] {
        let p = min(max(progress, 0), 1)
        let circleCenterX = detachGap + circleRadius
        let dotOrigin = detachGap + 3
        let positions: [CGFloat] = [
            dotOrigin,
            dotOrigin + dotSpacing,
            dotOrigin + dotSpacing * 2
        ]

        return positions.enumerated().map { index, targetX in
            let appearDelay = CGFloat(index) * 0.24
            let appear = min(max((p - appearDelay) / 0.52, 0), 1)
            let pop = WaterCurve.bead(appear)

            let startX = index == 0 ? circleCenterX : targetX
            let x = startX + (targetX - startX) * (index == 0 ? p : pop)

            let startR = index == 0 ? circleRadius : dotRadius
            let radius = startR + (dotRadius - startR) * (index == 0 ? p : pop)

            let bounce = loadingBounce(
                phase: bouncePhase,
                index: index,
                enabled: p >= 1
            )

            return LoadingDot(
                x: x,
                radius: max(radius * bounce.scale, 0.5),
                opacity: Double(pop * bounce.opacity)
            )
        }
    }

    private func loadingBounce(phase: CGFloat, index: Int, enabled: Bool) -> (scale: CGFloat, opacity: Double) {
        guard enabled, phase > 0 else { return (1, 1) }
        let offset = CGFloat(index) * 0.22
        let wave = sin((phase - offset) * .pi * 2) * 0.5 + 0.5
        let scale = 0.72 + 0.28 * wave
        let opacity = 0.45 + 0.55 * wave
        return (scale, opacity)
    }

    // MARK: - Formes

    /// Plat collé au bord gauche — très fin et haut.
    private func flatShape(protrusion: CGFloat, height: CGFloat, midY: CGFloat) -> Path {
        let w = max(protrusion, 0.3)
        let h = height
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY - h * 0.5))
        path.addCurve(
            to: CGPoint(x: 0, y: midY + h * 0.5),
            control1: CGPoint(x: w * 0.88, y: midY - h * 0.40),
            control2: CGPoint(x: w * 0.88, y: midY + h * 0.40)
        )
        path.closeSubpath()
        return path
    }

    /// Interpolation plat → cercle : reste haut/fin longtemps, se détache en s'arrondissant.
    private func morphShape(
        protrusion: CGFloat,
        roundness: CGFloat,
        leadingX: CGFloat,
        midY: CGFloat
    ) -> Path {
        let r = min(max(roundness, 0), 1)
        let w = max(protrusion, 0.3)
        let h = flatHeight + (circleRadius * 2 - flatHeight) * pow(r, 1.45)
        let corner = min(w, h) * 0.5 * pow(r, 0.85) + w * 0.04 * (1 - r)

        let rect = CGRect(x: leadingX, y: midY - h * 0.5, width: w, height: h)
        return Path(roundedRect: rect, cornerRadius: corner)
    }
}

// MARK: - Courbes

private enum WaterCurve {
    static func easeOut(_ t: CGFloat) -> CGFloat {
        let c = min(max(t, 0), 1)
        return 1 - pow(1 - c, 2.4)
    }

    static func easeIn(_ t: CGFloat) -> CGFloat {
        let c = min(max(t, 0), 1)
        return pow(c, 2.2)
    }

    static func easeInOut(_ t: CGFloat) -> CGFloat {
        let c = min(max(t, 0), 1)
        return c < 0.5 ? 2 * c * c : 1 - pow(-2 * c + 2, 2) / 2
    }

    /// Détachement lent au début, accélération quand le plat devient rond.
    static func detach(_ t: CGFloat) -> CGFloat {
        let c = min(max(t, 0), 1)
        if c < 0.45 {
            return pow(c / 0.45, 2.8) * 0.38
        }
        let u = (c - 0.45) / 0.55
        return 0.38 + (1 - pow(1 - u, 2)) * 0.62
    }

    /// Épaississement — lent tant que c'est plat.
    static func widen(_ t: CGFloat) -> CGFloat {
        let c = min(max(t, 0), 1)
        if c < 0.35 {
            return pow(c / 0.35, 2.6) * 0.22
        }
        let u = (c - 0.35) / 0.65
        return 0.22 + (1 - pow(1 - u, 2.2)) * 0.78
    }

    /// Glissement depuis le bord — lié à l'arrondi, accélère en fin de morph.
    static func detachLift(_ roundness: CGFloat) -> CGFloat {
        let c = min(max(roundness, 0), 1)
        if c < 0.12 { return 0 }
        let u = (c - 0.12) / 0.88
        return pow(u, 1.25)
    }

    static func bead(_ t: CGFloat) -> CGFloat {
        let c = min(max(t, 0), 1)
        return 1 - pow(1 - c, 3)
    }
}

struct CoachThinkingBlobPlaceholder: View {
    var body: some View {
        Color.clear
            .frame(height: 44)
            .coachResponseAnchor()
            .accessibilityLabel("Coach réfléchit")
    }
}

// MARK: - Ancrage vertical de la goutte (alignée sur la réponse en cours)

struct CoachResponseAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

extension View {
    func coachResponseAnchor() -> some View {
        background {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: CoachResponseAnchorKey.self,
                        value: geo.frame(in: .named("coachChatRoot"))
                    )
            }
        }
    }
}

struct CoachMessageFadeIn: ViewModifier {
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 5)
            .onAppear {
                withAnimation(.easeOut(duration: 0.18)) {
                    visible = true
                }
            }
    }
}

extension View {
    func coachMessageFadeIn() -> some View {
        modifier(CoachMessageFadeIn())
    }
}
