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
        if isRegularWidth(horizontalSizeClass) {
            let horizontalLimit = width - 96
            let verticalLimit = height * 0.40
            return min(380, max(300, min(horizontalLimit, verticalLimit)))
        }
        return min(width - 56, 296)
    }

    static func faceScanCameraZoom(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        isRegularWidth(horizontalSizeClass) ? 1.30 : 1.38
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
