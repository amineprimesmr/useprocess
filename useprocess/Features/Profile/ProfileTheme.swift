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

    static let horizontalPadding: CGFloat = 16
    static let heroBottomRadius: CGFloat = 32
    static let buttonCornerRadius: CGFloat = 14
    static let iconButtonSize: CGFloat = 44

    /// Zone visible sous la status bar.
    static let heroBodyHeight: CGFloat = 280
    static var heroTopInset: CGFloat { ProcessMainChromeMetrics.topSafeInset }
    /// Hauteur totale peinte depuis le haut de l'écran (WYSIWYG crop + affichage).
    static var heroCoverHeight: CGFloat { heroBodyHeight + heroTopInset }

    static var heroCoverWidth: CGFloat { max(UIScreen.main.bounds.width, 320) }

    /// Ratio largeur / hauteur du hero (recadrage WYSIWYG).
    static var heroCoverAspectRatio: CGFloat {
        heroCoverWidth / heroCoverHeight
    }

    /// Taille d'export = pixels exacts affichés sur l'appareil.
    static var heroCoverExportSize: CGSize {
        CGSize(width: heroCoverWidth, height: heroCoverHeight)
    }

    static func heroBottomShape(scale: CGFloat = 1) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: heroBottomRadius * scale,
            bottomTrailingRadius: heroBottomRadius * scale,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

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
    static var heroBottomShape: UnevenRoundedRectangle { heroBottomShape(scale: 1) }
}

typealias ProfilePressStyle = ProcessGlassPressStyle
