import SwiftUI

struct PoseGuidanceOverlay: View {
    let pose: ScanPoseKind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: frameWidth, height: frameHeight)
                .overlay {
                    Image(systemName: pose.icon)
                        .font(.system(size: pose.isFacePose ? 56 : 80))
                        .foregroundStyle(.white.opacity(0.25))
                }
        }
        .allowsHitTesting(false)
    }

    private var frameWidth: CGFloat {
        pose.isFacePose ? 220 : 260
    }

    private var frameHeight: CGFloat {
        pose.isFacePose ? 280 : 420
    }
}
