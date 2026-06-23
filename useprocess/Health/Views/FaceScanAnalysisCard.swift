import SwiftUI

/// Badge score visage (0–100) — même présentation % que l'analyse scan.
struct FaceWellnessScoreBadge: View {
    let score: Int
    var theme: AppTheme
    var style: Style = .compact

    enum Style {
        case compact
        case prominent
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: style == .compact ? 1 : 2) {
            Text("\(score)")
                .font(scoreFont)
                .foregroundStyle(theme.primaryText)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("%")
                .font(percentFont)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.horizontal, style == .compact ? 10 : 14)
        .padding(.vertical, style == .compact ? 5 : 8)
        .background(theme.cardBackground.opacity(style == .compact ? 0.8 : 0.6))
        .clipShape(RoundedRectangle(cornerRadius: style == .compact ? 10 : 12, style: .continuous))
        .accessibilityLabel("Score visage \(score) pour cent")
    }

    private var scoreFont: Font {
        switch style {
        case .compact:
            return .system(size: 15, weight: .bold)
        case .prominent:
            return .system(size: 28, weight: .black, design: .rounded)
        }
    }

    private var percentFont: Font {
        switch style {
        case .compact:
            return .system(size: 11, weight: .semibold)
        case .prominent:
            return .system(size: 14, weight: .semibold)
        }
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
