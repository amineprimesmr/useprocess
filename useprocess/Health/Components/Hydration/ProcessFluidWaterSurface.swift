import CoreGraphics
import Foundation
import SwiftUI

/// Eau en bas d'écran — pente volume-conservée (milieu fixe, bords montent/descendent).
enum ProcessFluidWaterSurface {
    static let maxFillRatio: CGFloat = 0.72
    private static let segmentCount = 28

    /// Amplitude de pente (fraction de la profondeur) : assez forte pour un suivi tactile net.
    private static let rollAmplitude: CGFloat = 0.62
    /// Tangage uniforme (fraction de profondeur).
    private static let pitchAmplitude: CGFloat = 0.18

    private static func waterDepth(height: CGFloat, fillLevel: CGFloat) -> CGFloat {
        min(1, max(0, fillLevel)) * height * maxFillRatio
    }

    static func surfaceY(
        atX x: CGFloat,
        width: CGFloat,
        height: CGFloat,
        fillLevel: CGFloat,
        roll: CGFloat,
        pitch: CGFloat,
        wavePhase: CGFloat
    ) -> CGFloat {
        guard width > 0, height > 0 else { return height }

        let depth = waterDepth(height: height, fillLevel: fillLevel)
        let restY = height - depth
        let clampedRoll = max(-1, min(1, roll))
        let clampedPitch = max(-1, min(1, pitch))
        let normalizedX = (x / width - 0.5) * 2

        // Volume conservé : le centre reste à restY + pitch.
        // roll > 0 → eau à droite → Y plus petit à droite (plus d'eau), plus grand à gauche.
        let midY = restY - clampedPitch * depth * pitchAmplitude
        let slope = -clampedRoll * normalizedX * depth * rollAmplitude
        let wave = CGFloat(sin(Double(wavePhase) + Double(x) * 0.022)) * 1.4

        let y = midY + slope + wave
        let topLimit = height * (1 - maxFillRatio) - 8
        return min(height - 2, max(topLimit, y))
    }

    static func surfacePath(
        width: CGFloat,
        height: CGFloat,
        fillLevel: CGFloat,
        roll: CGFloat,
        pitch: CGFloat,
        wavePhase: CGFloat
    ) -> Path {
        guard width > 0, height > 0 else { return Path() }

        var points: [CGPoint] = []
        points.reserveCapacity(segmentCount + 1)

        for index in 0...segmentCount {
            let x = CGFloat(index) / CGFloat(segmentCount) * width
            let y = surfaceY(
                atX: x,
                width: width,
                height: height,
                fillLevel: fillLevel,
                roll: roll,
                pitch: pitch,
                wavePhase: wavePhase
            )
            points.append(CGPoint(x: x, y: y))
        }

        var path = Path()
        path.move(to: points[0])

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let mid = CGPoint(x: (previous.x + current.x) * 0.5, y: (previous.y + current.y) * 0.5)
            path.addQuadCurve(to: current, control: mid)
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}
