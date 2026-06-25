import SwiftUI

/// Vignette carrée pour exercice / cardio / mobilité.
struct PlanTrainingMediaThumb: View {
    let assetName: String?
    var fallbackSystemImage: String = "figure.strengthtraining.traditional"
    var size: CGFloat = 52

    @Environment(\.appTheme) private var theme

    var body: some View {
        Group {
            if let assetName, ProcessAssetCatalog.contains(assetName) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.coachUserBubble.opacity(theme.isDark ? 0.35 : 0.55))
                    Image(systemName: fallbackSystemImage)
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundStyle(theme.onboardingAccent)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct PlanTrainingExerciseCard: View {
    let exercise: OriginExercise

    @Environment(\.appTheme) private var theme

    private var assetName: String? {
        TrainingAssetCatalog.exerciseAsset(for: exercise.name)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PlanTrainingMediaThumb(assetName: assetName)

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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HealthHubDesign.softCard(theme: theme))
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
                size: 44
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
