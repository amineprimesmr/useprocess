import SwiftUI

/// Vignette carrée pour exercice / cardio / mobilité.
struct PlanTrainingMediaThumb: View {
    let assetName: String?
    var fallbackSystemImage: String = "figure.strengthtraining.traditional"
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

/// Carte compacte pour le carrousel « Entraînement du jour ».
struct PlanTrainingExercisePreviewCard: View {
    let exercise: OriginExercise
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private let cardWidth: CGFloat = 156
    private let imageHeight: CGFloat = 128
    private let cornerRadius: CGFloat = 22

    private var assetName: String? {
        TrainingAssetCatalog.exerciseAsset(for: exercise.name)
    }

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    previewImage
                        .frame(height: imageHeight)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)

                    Text("\(exercise.sets)×\(exercise.reps)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.black.opacity(0.38)))
                        .padding(10)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !exercise.muscleGroup.isEmpty {
                        Text(exercise.muscleGroup.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.onboardingAccent.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.isDark ? Color(red: 0.13, green: 0.13, blue: 0.14) : theme.cardBackgroundStrong)
            }
            .frame(width: cardWidth)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                PlanTrainingCardReliefOverlay(cornerRadius: cornerRadius, isDark: theme.isDark)
            }
        }
        .buttonStyle(PlanTrainingCard3DPressStyle(restTilt: 4))
        .shadow(color: .black.opacity(theme.isDark ? 0.45 : 0.12), radius: 2, y: 2)
        .shadow(color: .black.opacity(theme.isDark ? 0.38 : 0.14), radius: 12, y: 7)
    }

    @ViewBuilder
    private var previewImage: some View {
        if let assetName, ProcessAssetCatalog.contains(assetName) {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .scaleEffect(1.12)
        } else {
            ZStack {
                theme.coachUserBubble.opacity(theme.isDark ? 0.35 : 0.55)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.onboardingAccent)
            }
        }
    }
}

struct PlanTrainingExerciseCard: View {
    let exercise: OriginExercise

    @Environment(\.appTheme) private var theme

    private var assetName: String? {
        TrainingAssetCatalog.exerciseAsset(for: exercise.name)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PlanTrainingMediaThumb(assetName: assetName, size: 72, cornerRadius: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Text("\(exercise.sets)×\(exercise.reps) · repos \(exercise.restSeconds)s")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                if !exercise.coachingCue.isEmpty {
                    Text(exercise.coachingCue)
                        .font(.caption)
                        .foregroundStyle(theme.primaryText.opacity(0.85))
                }
                if !exercise.muscleGroup.isEmpty {
                    Text(exercise.muscleGroup.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.onboardingAccent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.isDark ? Color(red: 0.13, green: 0.13, blue: 0.14) : theme.cardBackgroundStrong)
        }
        .overlay {
            PlanTrainingCardReliefOverlay(cornerRadius: 18, isDark: theme.isDark)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(theme.isDark ? 0.35 : 0.1), radius: 10, y: 5)
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
