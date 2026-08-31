import SwiftUI
import UIKit

// MARK: - Stretchy hero (pull-down overscroll — scroll normal inchangé)

/// Ancre le hero en haut et ne grandit que quand l’utilisateur tire la page vers le bas.
struct ProfileStretchyHeroFrame<Content: View>: View {
    let baseHeight: CGFloat
    @ViewBuilder let content: (_ totalHeight: CGFloat, _ stretch: CGFloat) -> Content

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("processMainScroll")).minY
            let stretch = max(0, minY)
            let totalHeight = baseHeight + stretch

            content(totalHeight, stretch)
                .frame(width: geo.size.width, height: totalHeight, alignment: .top)
                .offset(y: stretch > 0 ? -stretch : 0)
        }
        .frame(height: baseHeight)
    }
}

// MARK: - Empty hero (gradient + placeholder)


// MARK: - Cover hero (with photo)

private struct ProfileHeroBottomLightGlow: View {
    var height: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            RadialGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.04),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 1.05),
                startRadius: 0,
                endRadius: height * 1.15
            )

            LinearGradient(
                colors: [.clear, Color.white.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .allowsHitTesting(false)
    }
}


enum ProfileIdentityStyle {
    case inline, overlay
}

struct ProfileIdentityBlock: View {
    let displayName: String
    let isPrivate: Bool
    var style: ProfileIdentityStyle = .inline

    var body: some View {
        HStack(spacing: 8) {
            Text(displayName)
                .font(.system(size: style == .overlay ? 30 : 26, weight: .bold))
                .foregroundStyle(style == .overlay ? .white : ProfileTheme.textPrimary)

            if isPrivate {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(style == .overlay ? .white.opacity(0.9) : ProfileTheme.textSecondary)
            }
        }
        .shadow(
            color: style == .overlay ? .black.opacity(0.35) : .clear,
            radius: 6,
            y: 2
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - Sheets

struct ProfileShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
