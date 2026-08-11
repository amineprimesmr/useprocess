import SwiftUI

enum MealDebloatScorePalette {
    static func color(for score: Int) -> Color {
        switch score {
        case 88...100: return Color(red: 0.25, green: 0.78, blue: 0.52)
        case 76..<88: return Color(red: 0.42, green: 0.72, blue: 0.95)
        case 64..<76: return Color(red: 0.95, green: 0.72, blue: 0.24)
        default: return Color(red: 0.96, green: 0.47, blue: 0.30)
        }
    }
}

struct MealDebloatScorePill: View {
    let assessment: MealDebloatAssessment
    var usesDarkImageStyle = false

    @Environment(\.appTheme) private var theme

    var body: some View {
        let scoreColor = MealDebloatScorePalette.color(for: assessment.score)

        HStack(spacing: 6) {
            Image(systemName: "drop.degreesign.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(scoreColor)

            Text(assessment.scoreText)
                .font(.caption.weight(.heavy))
                .monospacedDigit()

            Text(AppCopy.t("Debloat", en: "Debloat"))
                .font(.caption2.weight(.semibold))
                .opacity(0.78)
        }
        .foregroundStyle(usesDarkImageStyle ? Color.white : theme.primaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            let pill = Capsule(style: .continuous)
            ZStack {
                pill.fill(scoreColor.opacity(usesDarkImageStyle ? 0.22 : 0.14))
                pill
                    .fill(.clear)
                    .processGlassEffect(in: pill, interactive: false)
            }
        }
        .shadow(color: .black.opacity(theme.isDark || usesDarkImageStyle ? 0.24 : 0.08), radius: 9, y: 4)
        .accessibilityLabel(AppCopy.t("Score Debloat \(assessment.score) sur 100", en: "Debloat score \(assessment.score) out of 100"))
        .accessibilityHint(assessment.isEstimated ? AppCopy.t("Estimation nutritionnelle", en: "Nutrition estimate") : assessment.label)
    }
}

/// Pill score Debloat — liquid glass (hero repas, détail).
struct MealDebloatScoreGlassPill: View {
    let assessment: MealDebloatAssessment

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "drop.degreesign.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(MealDebloatScorePalette.color(for: assessment.score))

            Text(assessment.scoreText)
                .font(.caption.weight(.heavy))
                .monospacedDigit()

            Text(AppCopy.t("Debloat", en: "Debloat"))
                .font(.caption2.weight(.semibold))
                .opacity(0.72)
        }
        .foregroundStyle(theme.primaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule(style: .continuous)
                .fill(.clear)
                .processGlassEffect(in: Capsule(style: .continuous), interactive: false)
        }
        .shadow(color: .black.opacity(theme.isDark ? 0.30 : 0.10), radius: 10, y: 4)
        .accessibilityLabel(AppCopy.t("Score Debloat \(assessment.score) sur 100", en: "Debloat score \(assessment.score) out of 100"))
        .accessibilityHint(assessment.isEstimated ? AppCopy.t("Estimation nutritionnelle", en: "Nutrition estimate") : assessment.label)
    }
}

struct MealDebloatScoreFooter: View {
    let assessment: MealDebloatAssessment

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(assessment.score) / 100)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(assessment.scoreText)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(assessment.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text("K/Na \(assessment.balance.ratioLabel)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            MealDebloatScorePalette.color(for: assessment.score),
                            Color(red: 0.28, green: 0.56, blue: 0.88)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.5)
                }
        }
    }
}

struct MealDebloatScoreBreakdownView: View {
    let assessment: MealDebloatAssessment
    var compact = false

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: compact ? 8 : 11) {
            scoreBar(
                title: AppCopy.t("Équilibre hydrique", en: "Fluid balance"),
                value: assessment.electrolyteScore,
                color: MealElectrolytePalette.potassium
            )
            scoreBar(
                title: AppCopy.t("Confort digestif", en: "Digestive comfort"),
                value: assessment.digestiveScore,
                color: Color(red: 0.43, green: 0.70, blue: 0.96)
            )
            scoreBar(
                title: AppCopy.t("Qualité du repas", en: "Meal quality"),
                value: assessment.foodQualityScore,
                color: Color(red: 0.75, green: 0.58, blue: 0.96)
            )
        }
    }

    private func scoreBar(title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Text("\(value)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.cardStroke.opacity(0.25))
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: compact ? 5 : 7)
        }
    }
}

struct MealDebloatScoreDetailCard: View {
    let assessment: MealDebloatAssessment

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 13) {
                MealDebloatScoreGlassPill(assessment: assessment)

                VStack(alignment: .leading, spacing: 4) {
                    Text(assessment.label)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                    Text(assessment.summary)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            MealDebloatScoreBreakdownView(assessment: assessment)

            HStack(spacing: 8) {
                Label("K/Na \(assessment.balance.ratioLabel)", systemImage: "arrow.left.arrow.right")
                Label(
                    assessment.balance.isDebloatOptimized ? AppCopy.t("Électrolytes optimisés", en: "Electrolytes optimized") : AppCopy.t("Électrolytes à ajuster", en: "Electrolytes to adjust"),
                    systemImage: assessment.balance.isDebloatOptimized
                        ? "checkmark.seal.fill"
                        : "exclamationmark.circle.fill"
                )
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)

            if let caution = assessment.caution {
                Label(caution, systemImage: "person.crop.circle.badge.questionmark")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(
                assessment.isEstimated
                    ? "≈ Estimation basée sur les ingrédients. Le score peut varier selon les quantités et ta tolérance."
                    : AppCopy.t("Estimation nutritionnelle — la tolérance digestive reste individuelle.", en: "Nutrition estimate — digestive tolerance is still individual.")
            )
            .font(.caption2)
            .foregroundStyle(theme.secondaryText.opacity(0.78))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.cardBackgroundStrong)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(theme.cardStroke, lineWidth: 0.5)
                }
        }
    }
}
