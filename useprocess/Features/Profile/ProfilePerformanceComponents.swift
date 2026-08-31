import SwiftUI
import UIKit

enum ProfileAnalyticsRange: String, CaseIterable, Identifiable {
    case week = "Semaine"
    case month = "Mois"
    case all = "Tout"

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .week: return AppCopy.t("Semaine", en: "Week")
        case .month: return AppCopy.t("Mois", en: "Month")
        case .all: return AppCopy.t("Tout", en: "All")
        }
    }

    /// Fenêtre par défaut sur le profil — 30 derniers jours pour limiter le coût de rendu.
    static let profileDefault: ProfileAnalyticsRange = .month
}

struct ProfileAnalyticsPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let value: Double
}

enum ProfilePerformancePalette {
    static let peach = Color(red: 1.0, green: 0.66, blue: 0.52)
    static let blue = Color(red: 0.33, green: 0.72, blue: 1.0)
}

// MARK: - Top bar


// MARK: - Identité


private struct ProfileAvatarButton: View {
    @Environment(\.appTheme) private var theme

    let image: UIImage?
    let onPhotoTap: (CGPoint) -> Void

    private let size: CGFloat = 72

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(theme.cardBackgroundStrong)

                    Image(systemName: "person.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(theme.cardStroke, lineWidth: 0.5)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onEnded { value in onPhotoTap(value.location) }
        )
        .accessibilityLabel(AppCopy.t("Photo de profil", en: "Profile Photo"))
        .accessibilityHint(AppCopy.t("Touchez pour la modifier", en: "Tap to edit"))
    }
}
