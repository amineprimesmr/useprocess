import SwiftUI

/// Vignette carrée pour exercice / cardio / mobilité.
struct PlanTrainingMediaThumb: View {
    let assetName: String?
    var fallbackSystemImage: String = "figure.run"
    var size: CGFloat = 64
    var cornerRadius: CGFloat = 14

    @Environment(\.appTheme) private var theme

    var body: some View {
        Group {
            if let assetName, ProcessAssetCatalog.contains(assetName) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.08)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(theme.coachUserBubble.opacity(theme.isDark ? 0.35 : 0.55))
                    Image(systemName: fallbackSystemImage)
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundStyle(theme.onboardingAccent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(theme.isDark ? 0.22 : 0.45),
                            Color.black.opacity(theme.isDark ? 0.2 : 0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
        }
        .shadow(color: .black.opacity(theme.isDark ? 0.35 : 0.12), radius: 6, y: 3)
    }
}

struct PlanTrainingBlockRow: View {
    let line: String
    var fallbackSystemImage: String = "figure.walk"

    @Environment(\.appTheme) private var theme

    private var assetName: String? {
        TrainingAssetCatalog.blockAsset(for: line)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PlanTrainingMediaThumb(
                assetName: assetName,
                fallbackSystemImage: fallbackSystemImage,
                size: 52,
                cornerRadius: 12
            )

            Text(line)
                .font(.subheadline)
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Relief partagé (utilisé par les cartes training)

struct PlanTrainingCardReliefOverlay: View {
    let cornerRadius: CGFloat
    let isDark: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isDark ? 0.16 : 0.38),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(isDark ? 0.28 : 0.12)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isDark ? 0.26 : 0.55),
                            Color.white.opacity(isDark ? 0.05 : 0.14),
                            Color.black.opacity(isDark ? 0.35 : 0.14)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Carte contenu élevée (détail repas, blocs protocole)


/// Tuile inset glass — lignes ingrédients / étapes dans une carte 3D.

struct PlanTrainingCard3DPressStyle: ButtonStyle {
    var restTilt: Double = 5.5

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .rotation3DEffect(
                .degrees(configuration.isPressed ? 2 : restTilt),
                axis: (x: 1, y: 0.06, z: 0),
                anchor: .center,
                perspective: 0.48
            )
            .animation(.spring(response: 0.32, dampingFraction: 0.74), value: configuration.isPressed)
    }
}

/// Press léger pour les deux cartes entraînement côte à côte (pas de tilt 3D).
struct PlanTrainingCardPairedPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: configuration.isPressed)
    }
}
