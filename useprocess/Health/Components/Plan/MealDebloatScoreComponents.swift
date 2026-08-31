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

    /// Rouge (nul) → orange (moyen) → jaune (bof) → vert (bien).
    static func tieredColor(for score: Int) -> Color {
        switch score {
        case 75...100: return Color(red: 0.30, green: 0.80, blue: 0.42) // vert
        case 60..<75: return Color(red: 0.95, green: 0.80, blue: 0.20) // jaune
        case 40..<60: return Color(red: 0.96, green: 0.58, blue: 0.20) // orange
        default: return Color(red: 0.93, green: 0.30, blue: 0.28) // rouge
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


struct MealDebloatScoreBreakdownView: View {
    let assessment: MealDebloatAssessment
    var compact = false

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: compact ? 8 : 11) {
            scoreBar(
                title: AppCopy.t("Équilibre hydrique", en: "Fluid balance"),
                value: assessment.electrolyteScore
            )
            scoreBar(
                title: AppCopy.t("Confort digestif", en: "Digestive comfort"),
                value: assessment.digestiveScore
            )
            scoreBar(
                title: AppCopy.t("Qualité du repas", en: "Meal quality"),
                value: assessment.foodQualityScore
            )
        }
    }

    private func scoreBar(title: String, value: Int) -> some View {
        let color = MealDebloatScorePalette.tieredColor(for: value)

        return VStack(alignment: .leading, spacing: 5) {
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
            .animation(.easeInOut(duration: 0.3), value: value)
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
