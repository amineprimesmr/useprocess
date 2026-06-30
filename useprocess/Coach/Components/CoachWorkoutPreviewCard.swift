import SwiftUI

struct CoachWorkoutPreviewCard: View {
    let workout: CoachWorkoutPreview

    @Environment(\.appTheme) private var theme

    private let cardShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            VStack(spacing: 0) {
                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                    exerciseRow(exercise)

                    if index < workout.exercises.count - 1 {
                        Divider()
                            .overlay(theme.secondaryText.opacity(0.12))
                    }
                }
            }

            if let footer = workout.footer, !footer.isEmpty {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .processGlassEffect(in: cardShape, interactive: false)
    }

    private var headerThumbAsset: String? {
        workout.exercises.lazy
            .compactMap { TrainingAssetCatalog.exerciseAsset(for: $0.name) }
            .first
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            PlanTrainingMediaThumb(
                assetName: headerThumbAsset,
                fallbackSystemImage: "figure.strengthtraining.traditional",
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.primaryText)

                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        parts.append("\(workout.exercises.count) exercices")
        if let duration = workout.durationMinutes {
            parts.append("\(duration) min")
        }
        return parts.joined(separator: " · ")
    }

    private func exerciseRow(_ exercise: CoachExercisePreview) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            PlanTrainingMediaThumb(
                assetName: TrainingAssetCatalog.exerciseAsset(for: exercise.name),
                size: 40
            )

            Text(exercise.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(exercise.sets)×\(exercise.reps)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.onboardingAccent)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
    }
}

struct CoachAssistantMessageBody: View {
    let text: String
    var font: Font = .system(size: 17, weight: .regular)
    var lineSpacing: CGFloat = 4
    var color: Color = .primary

    var body: some View {
        let segments = CoachStructuredMessageParser.segments(from: text)

        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .paragraph(let paragraph):
                    CoachFormattedText(
                        text: paragraph,
                        font: font,
                        lineSpacing: lineSpacing,
                        color: color
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                case .workout(let workout):
                    CoachWorkoutPreviewCard(workout: workout)
                }
            }
        }
    }
}
