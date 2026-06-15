import SwiftUI
import UIKit

enum ProfileTheme {
    static let background = ProcessColors.background
    static let surface = ProcessColors.secondaryBackground
    static let surfaceElevated = Color(.tertiarySystemBackground)
    static let textPrimary = ProcessColors.textPrimary
    static let textSecondary = ProcessColors.textSecondary
    static let textPlaceholder = Color(.placeholderText)
    static let separator = ProcessColors.border
    static let dashedBorder = Color.primary.opacity(0.22)

    static let avatarAccent = Color(red: 0.71, green: 0.69, blue: 0.0)
    static let accentDot = Color.red

    static let emptyGradientCore = Color.primary.opacity(0.08)
    static let emptyGradientMid = Color.primary.opacity(0.04)
    static let emptyGradientEdge = ProcessColors.background

    static let emptyHeroIconSize: CGFloat = 26
    static let emptyHeroTopClearance: CGFloat = 152

    static let horizontalPadding: CGFloat = 16
    static let heroBottomRadius: CGFloat = 32
    static let buttonCornerRadius: CGFloat = 14
    static let iconButtonSize: CGFloat = 44
    static var heroHeight: CGFloat = 430
    static var emptyHeroHeight: CGFloat = 300
    static var topSafeInset: CGFloat { UIApplication.safeAreaTop }
    /// Hero edge-to-edge : hauteur visible + zone sous Dynamic Island / status bar.
    static var heroTotalHeight: CGFloat { heroHeight + topSafeInset }
    static var emptyHeroTotalHeight: CGFloat { emptyHeroHeight + topSafeInset }
    /// Extension au-dessus du layout pour peindre derrière la status bar.
    static var heroSafeAreaExtension: CGFloat { topSafeInset + 8 }
    static var heroTopBlurHeight: CGFloat { topSafeInset + 96 }
    static var topBarBlurHeight: CGFloat { topSafeInset + 56 }
    static let pinWidth: CGFloat = 118
    static let pinHeight: CGFloat = 168

    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let quickSpring = Animation.spring(response: 0.28, dampingFraction: 0.9)
}

struct ProfileEmptyHeroBackground: View {
    var body: some View {
        ZStack {
            ProfileTheme.background

            RadialGradient(
                colors: [
                    ProfileTheme.emptyGradientCore,
                    ProfileTheme.emptyGradientMid,
                    ProfileTheme.emptyGradientEdge
                ],
                center: UnitPoint(x: 0.5, y: 0.48),
                startRadius: 12,
                endRadius: 150
            )

            LinearGradient(
                colors: [
                    ProfileTheme.emptyGradientEdge,
                    ProfileTheme.emptyGradientEdge.opacity(0.35),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.34)
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    ProfileTheme.emptyGradientEdge.opacity(0.28),
                    ProfileTheme.emptyGradientEdge
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.68),
                endPoint: .bottom
            )
        }
    }
}

extension ProfileTheme {
    static var heroBottomShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: heroBottomRadius,
            bottomTrailingRadius: heroBottomRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }
}

typealias ProfilePressStyle = ProcessGlassPressStyle
