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

/// Analyse Claude — résumé et signaux uniquement (pas de conseils).
struct FaceScanAnalysisCard: View {
    let analysis: FaceScanAnalysisContent
    var theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(analysis.summary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !analysis.signals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(analysis.signals, id: \.self) { signal in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(theme.onboardingAccent.opacity(0.85))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(signal)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !analysis.evolution.isEmpty {
                Text(analysis.evolution)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct FaceScanMetricsRow: View {
    let markers: FaceWellnessMarkers
    var relativeSignals: FaceScanRelativeSignals?
    var trend: FaceScanTrend?
    var theme: AppTheme

    private var displayResult: FaceScanResult {
        FaceScanResult(
            userId: "",
            markers: markers,
            relativeSignals: relativeSignals
        )
    }

    private var previousResult: FaceScanResult? {
        guard let trend else { return nil }
        return FaceScanResult(
            userId: "",
            markers: FaceWellnessMarkers(
                puffinessScore: markers.puffinessScore - trend.puffiness,
                underEyeFatigueScore: markers.underEyeFatigueScore - trend.underEyeFatigue,
                jawTensionScore: markers.jawTensionScore - trend.jawTension,
                facialSymmetryScore: markers.facialSymmetryScore - trend.facialSymmetry,
                skinClarityScore: markers.skinClarityScore - trend.skinClarity,
                notes: []
            )
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(FaceScanMetricDisplay.items(for: displayResult, previous: previousResult)) { item in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                        Text(item.subtitle)
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText.opacity(0.85))
                        Text(item.status)
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Text(item.comparison)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(comparisonColor(item.comparisonKind))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.cardBackground.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func comparisonColor(_ kind: FaceScanMetricDisplay.ComparisonKind) -> Color {
        switch kind {
        case .better: return .green
        case .worse: return .orange
        case .stable, .reference: return theme.secondaryText
        }
    }
}
