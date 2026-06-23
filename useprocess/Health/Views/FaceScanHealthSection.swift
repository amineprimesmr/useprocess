import SwiftUI

struct FaceScanHealthSection: View {
    @Environment(\.appTheme) private var theme

    let latest: FaceScanResult?
    let previous: FaceScanResult?
    let history: [FaceScanResult]
    let streakDays: Int
    let daysSinceLastScan: Int?
    let daysUntilNextScan: Int?
    let isScanDue: Bool
    let faceDayScore: Int?
    let correlations: [FaceScanCorrelationInsight]
    var onScan: () -> Void
    var onHistory: () -> Void

    private var trend: FaceScanTrend? {
        guard let latest, let previous else { return nil }
        return latest.delta(from: previous)
    }

    private var analysis: FaceScanAnalysisContent {
        guard let latest else { return .empty }
        return CoachEngine.parsedFaceAnalysis(for: latest)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Label("Scan visage", systemImage: "face.smiling")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)

                Spacer()

                if let faceDayScore {
                    FaceWellnessScoreBadge(score: faceDayScore, theme: theme)
                }

                if streakDays > 0 {
                    Text("\(streakDays)×3j 🔥")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
            }

            dailyNudge

            if history.count >= 2 {
                FaceScanTrendChartView(history: history, theme: theme)
            }

            if !correlations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Corrélations détectées")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .textCase(.uppercase)

                    ForEach(correlations.prefix(3)) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: insight.icon)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(width: 16)
                            Text(insight.message)
                                .font(.caption)
                                .foregroundStyle(theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let latest {
                if let confidence = latest.scanConfidence {
                    Text("\(FaceWellnessScore.confidenceLabel(for: confidence)) · score relatif à ta baseline, pas à ta forme de visage.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                FaceScanMetricsRow(
                    markers: latest.markers,
                    relativeSignals: latest.relativeSignals,
                    trend: trend,
                    theme: theme
                )

                if analysis.isValid {
                    FaceScanAnalysisCard(analysis: analysis, theme: theme)
                } else if let raw = latest.claudeAnalysis {
                    Text(raw)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(4)
                }

                Text("Dernier scan : \(latest.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
            } else {
                Text("Scanne ton visage chaque jour pour suivre gonflement, cernes, cortisol et récupération.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }

            HStack(spacing: 10) {
                Button(action: onScan) {
                    Label(isScanDue ? "Nouveau scan" : "Scanner quand même", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primaryText)

                Button(action: onHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .tint(theme.primaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }

    @ViewBuilder
    private var dailyNudge: some View {
        if latest == nil {
            Label("Premier scan à faire", systemImage: "exclamationmark.circle")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
        } else if isScanDue {
            Label("Scan du jour à faire", systemImage: "bell.badge")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
        } else if let remaining = daysUntilNextScan, remaining == 1 {
            Label("Prochain scan demain", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        } else if let remaining = daysUntilNextScan, remaining > 1 {
            Label("Prochain scan dans \(remaining) jours", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        } else if let days = daysSinceLastScan, days == 0 {
            Label("Scan enregistré aujourd'hui", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
            }
    }
}
