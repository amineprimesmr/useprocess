import SwiftUI

/// Badge appréciation visage — texte lisible (gonflé, fatigué…) plutôt que score %.
struct FaceWellnessAppreciationBadge: View {
    let appreciation: FaceWellnessScore.Appreciation
    var theme: AppTheme
    var style: Style = .compact

    enum Style {
        case compact
        case prominent
    }

    var body: some View {
        Text(appreciation.displayText)
            .font(textFont)
            .foregroundStyle(foregroundColor)
            .lineLimit(style == .compact ? 2 : 3)
            .multilineTextAlignment(style == .prominent ? .leading : .center)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, style == .compact ? 10 : 14)
            .padding(.vertical, style == .compact ? 6 : 10)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: style == .compact ? 10 : 12, style: .continuous))
            .accessibilityLabel(appreciation.displayText)
    }

    private var textFont: Font {
        switch style {
        case .compact:
            return .system(size: 13, weight: .bold)
        case .prominent:
            return .system(size: 22, weight: .bold)
        }
    }

    private var foregroundColor: Color {
        switch appreciation.tone {
        case .excellent, .good:
            return theme.primaryText
        case .moderate:
            return theme.primaryText
        case .elevated:
            return Color.orange
        case .stressed:
            return Color(red: 0.92, green: 0.42, blue: 0.28)
        }
    }

    private var backgroundColor: Color {
        switch appreciation.tone {
        case .excellent, .good:
            return theme.cardBackground.opacity(style == .compact ? 0.8 : 0.6)
        case .moderate:
            return theme.cardBackground.opacity(0.75)
        case .elevated:
            return Color.orange.opacity(theme.isDark ? 0.18 : 0.12)
        case .stressed:
            return Color.red.opacity(theme.isDark ? 0.16 : 0.10)
        }
    }
}

/// Conservé pour compat — préférer `FaceWellnessAppreciationBadge`.
struct FaceWellnessScoreBadge: View {
    let score: Int
    var theme: AppTheme
    var style: Style = .compact

    enum Style {
        case compact
        case prominent
    }

    private var appreciation: FaceWellnessScore.Appreciation {
        FaceWellnessScore.appreciation(forScore: score)
    }

    var body: some View {
        FaceWellnessAppreciationBadge(
            appreciation: appreciation,
            theme: theme,
            style: style == .compact ? .compact : .prominent
        )
    }
}

struct FaceScanAnalysisCard: View {
    let analysis: FaceScanAnalysisContent
    var theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(analysis.summary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            if !analysis.signals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(analysis.signals, id: \.self) { signal in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.orange.opacity(0.85))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(signal)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                }
            }

            if !analysis.evolution.isEmpty {
                Text(analysis.evolution)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            if !analysis.tips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Conseils")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .textCase(.uppercase)

                    ForEach(Array(analysis.tips.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption2.weight(.bold))
                                .frame(width: 18, height: 18)
                                .background(theme.cardStroke.opacity(0.5))
                                .clipShape(Circle())
                            Text(tip)
                                .font(.caption)
                                .foregroundStyle(theme.primaryText)
                        }
                    }
                }
            }
        }
    }
}

struct FaceScanMetricsRow: View {
    let markers: FaceWellnessMarkers
    var relativeSignals: FaceScanRelativeSignals?
    var trend: FaceScanTrend?
    var theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let relativeSignals {
                Text(relativeSignals.baselineLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metric(
                    "Gonflement",
                    markers.puffinessScore,
                    relativeSignals?.puffinessDelta ?? trend?.puffiness,
                    higherIsWorse: true,
                    deltaMode: relativeSignals == nil ? .previous : .baseline
                )
                metric(
                    "Cernes",
                    markers.underEyeFatigueScore,
                    relativeSignals?.underEyeFatigueDelta ?? trend?.underEyeFatigue,
                    higherIsWorse: true,
                    deltaMode: relativeSignals == nil ? .previous : .baseline
                )
                metric(
                    "Mâchoire",
                    markers.jawTensionScore,
                    relativeSignals?.jawTensionDelta ?? trend?.jawTension,
                    higherIsWorse: true,
                    deltaMode: relativeSignals == nil ? .previous : .baseline
                )
                metric(
                    "Peau",
                    markers.skinClarityScore,
                    relativeSignals?.skinClarityDelta ?? trend?.skinClarity,
                    higherIsWorse: false,
                    deltaMode: relativeSignals == nil ? .previous : .baseline
                )
            }
        }
    }

    private enum DeltaMode {
        case previous
        case baseline
    }

    private func metric(
        _ title: String,
        _ value: Int,
        _ delta: Int?,
        higherIsWorse: Bool,
        deltaMode: DeltaMode
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
                Text("%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                if let delta, delta != 0 {
                    Text(deltaLabel(delta, mode: deltaMode))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(deltaColor(delta, higherIsWorse: higherIsWorse))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(theme.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func deltaLabel(_ delta: Int, mode: DeltaMode) -> String {
        let prefix = mode == .baseline ? "base " : ""
        return prefix + (delta > 0 ? "+\(delta)" : "\(delta)")
    }

    private func deltaColor(_ delta: Int, higherIsWorse: Bool) -> Color {
        let improved = higherIsWorse ? delta < 0 : delta > 0
        if improved { return .green }
        if delta == 0 { return theme.secondaryText }
        return .orange
    }
}
