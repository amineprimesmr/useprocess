import SwiftUI

/// Overlay squelette temps réel — Vision `.leftMirrored` = aperçu selfie.
struct BodySkeletonOverlayView: View {
    let landmarks: [BodyLandmark]
    let isReady: Bool

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let visible = landmarks.filter { $0.confidence >= 0.2 }
                guard visible.count >= 3 else { return }

                let jointColor = isReady ? Color.green : Color.white.opacity(0.9)
                let boneColor = isReady ? Color.green.opacity(0.9) : Color.white.opacity(0.75)
                let jointRadius: CGFloat = isReady ? 9 : 7
                let lineWidth: CGFloat = isReady ? 5 : 4

                var points: [String: CGPoint] = [:]
                for lm in visible {
                    points[lm.name] = CGPoint(
                        x: CGFloat(lm.x) * size.width,
                        y: (1 - CGFloat(lm.y)) * size.height
                    )
                }

                for (a, b) in boneConnections {
                    guard let p1 = points[a], let p2 = points[b] else { continue }
                    guard hypot(p1.x - p2.x, p1.y - p2.y) < maxBoneLength(in: size) else { continue }

                    var path = Path()
                    path.move(to: p1)
                    path.addLine(to: p2)
                    context.stroke(path, with: .color(boneColor), lineWidth: lineWidth)
                }

                for lm in visible {
                    guard let pt = points[lm.name] else { continue }
                    let rect = CGRect(x: pt.x - jointRadius, y: pt.y - jointRadius,
                                      width: jointRadius * 2, height: jointRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(jointColor))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }

    private func maxBoneLength(in size: CGSize) -> CGFloat {
        min(size.width, size.height) * 0.55
    }

    private var boneConnections: [(String, String)] {
        [
            ("nose", "neck"),
            ("neck", "left_shoulder"), ("neck", "right_shoulder"),
            ("left_shoulder", "left_elbow"), ("left_elbow", "left_wrist"),
            ("right_shoulder", "right_elbow"), ("right_elbow", "right_wrist"),
            ("neck", "root"),
            ("root", "left_hip"), ("root", "right_hip"),
            ("left_hip", "left_knee"), ("left_knee", "left_ankle"),
            ("right_hip", "right_knee"), ("right_knee", "right_ankle")
        ]
    }
}
