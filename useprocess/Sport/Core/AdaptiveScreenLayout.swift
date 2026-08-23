import SwiftUI

/// Métriques de layout adaptatif iPhone / iPad (regular width, Stage Manager, Split View).
enum AdaptiveScreenLayout {
    static let paywallMaxWidth: CGFloat = 560
    static let faceScanColumnMaxWidth: CGFloat = 520
    static let onboardingChatMaxWidth: CGFloat = 640
    static let mainShellMaxWidth: CGFloat = 760

    static func isRegularWidth(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        sizeClass == .regular || LayoutConstants.isIPad
    }

    static func faceScanViewportDiameter(
        width: CGFloat,
        height: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> CGFloat {
        let safeWidth = width.isFinite ? max(width, 0) : 0
        let safeHeight = height.isFinite ? max(height, 0) : 0

        if isRegularWidth(horizontalSizeClass) {
            let horizontalLimit = safeWidth - 96
            let verticalLimit = safeHeight * 0.40
            return min(380, max(300, min(horizontalLimit, verticalLimit)))
        }
        return max(200, min(safeWidth - 56, 296))
    }

    static func faceScanCameraZoom(horizontalSizeClass _: UserInterfaceSizeClass?) -> CGFloat {
        ProcessScanCamera.frontPreviewLayoutZoom
    }

    static func biometricZoneSize(containerWidth: CGFloat) -> CGFloat {
        min(380, max(260, containerWidth - 48))
    }

    static func mediaPreviewHeight(containerWidth: CGFloat, isRegular: Bool) -> CGFloat {
        isRegular ? min(360, containerWidth * 0.42) : 260
    }
}

private struct RegularWidthContainerModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if AdaptiveScreenLayout.isRegularWidth(horizontalSizeClass) {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// Centre et limite la largeur sur iPad / regular horizontal size class.
    func regularWidthContainer(maxWidth: CGFloat = LayoutConstants.maxContentWidth) -> some View {
        modifier(RegularWidthContainerModifier(maxWidth: maxWidth))
    }
}
